#!/usr/bin/env python

from tqdm import tqdm
import torch
import torch.nn.functional as F
from torch.distributions import constraints

from numpy.lib.arraysetops import unique

import pyro
from pyro.optim import Adam
from pyro.infer import SVI, TraceGraph_ELBO
from pyro.distributions import TorchDistribution
from pyro.distributions.util import broadcast_shape
from pyro.distributions import Categorical, Bernoulli, Beta, Uniform, Dirichlet

# Constants
NUCSET = set('ACGT')

# Noise model for k-mers
class KmerNoiseDist(TorchDistribution):

    """
    Noise distribution p(x|z) modeling:

        i. Mutational noise: models effect of clonal mutations.

        ii. Sequencing noise: models effect of sequencing errors.

    """

    arg_constraints = {}

    # TODO: define support

    def __init__(self,bin_mean_kmer,noise_level,validate_args=None):

        # Register mean k-mer in binary format
        self.bin_mean_kmer = bin_mean_kmer
        self.succ_probs = torch.full(bin_mean_kmer.shape, 1.-noise_level)

        # Batch shape. Want to leave dim=-1 for latent
        batch_shape = broadcast_shape([bin_mean_kmer.shape[-1],bin_mean_kmer.shape[-2]])

        # Event shape defines what dimensions are dependent
        event_shape = ()
        super().__init__(batch_shape, event_shape, validate_args=validate_args)

    def sample(self,sample_shape=torch.Size()):

        dec_kmers = []
        len_kmers = self.batch_shape[-2] // 2       # dim=-2 contains length of k-mer
        num_kmers = self.batch_shape[-1]            # dim=-1 is number of k-mers

        # Get all k-mers (batch_shape)
        for i in range(num_kmers):
            dec_kmers.append(dec_seq(self.bin_mean_kmer[i,:]))

        # Generate noisy versions of k-mer
        noisy_kmers_out = []
        for i in range(num_kmers):
            noisy_kmer = ''
            kmer = dec_kmers[i]
            for j in range(len_kmers):
                nuc = kmer[j]
                if torch.bernoulli(self.succ_probs[i,j])==1:
                    noisy_kmer += nuc
                else:
                    mod_sucseq = tuple(NUCSET.difference(set(nuc)))
                    idx = torch.multinomial(torch.tensor([0.333,0.333,0.333]),1)
                    noisy_kmer += mod_sucseq[idx]
            noisy_kmers_out.append(enc_seq(noisy_kmer))

        # Reshape in form of true k-mers
        noisy_kmers_out = torch.stack(noisy_kmers_out)

        return torch.reshape(noisy_kmers_out,self.bin_mean_kmer.shape)

    def log_prob(self,value):

        len_kmers = self.batch_shape[-2]        # dim=-2 contains length of k-mer
        num_kmers = self.batch_shape[-1]        # dim=-1 is number of k-mers

        # Add up to obtain log_p
        log_p = torch.zeros(size=self.batch_shape)
        for i in range(num_kmers):
            for j in range(len_kmers):
                # Note we need to invert indices here due to batch_shape convention
                log_p[j,i] += torch.log(self.succ_probs[i,j]) if self.bin_mean_kmer[i,j]==value[i,j] else torch.log(1.-self.succ_probs[i,j])

        return log_p

    def expand(self, batch_shape, _instance=None):

        new = self._get_checked_instance(KmerNoiseDist, _instance)

        new.bin_mean_kmer = self.bin_mean_kmer.expand([batch_shape[-1],batch_shape[-2]])
        new.succ_probs = self.succ_probs.expand([batch_shape[-1],batch_shape[-2]])

        super(KmerNoiseDist, new).__init__(batch_shape, self.event_shape, validate_args=False)
        new._validate_args = self._validate_args
        return new

# Categorical distribution for latent k-mers (used both for base measure G0, and posterior q)
class CategAtoms(TorchDistribution):

    """
    Categorical distribution over a set of k-mers specified through supp argument.
    """

    arg_constraints = {}

    # TODO: define support?

    def __init__(self,gamma,supp,validate_args=None):

        # Register class parameters
        self.supp = supp
        self.gamma = gamma
        self.len_supp = gamma.shape[-1]

        # Store shape
        batch_shape = (gamma.shape[-2],)
        event_shape = (supp.shape[-1],)

        # Event shape defines what dimensions are dependent
        super().__init__(batch_shape, event_shape, validate_args=validate_args)

    def sample(self,sample_shape=torch.Size()):

        # Sample from multinomial posterior
        ids = torch.multinomial(self.gamma,1).flatten()

        # Retrieve sampled k-mers
        samp_kmers = [self.supp[i] for i in ids]

        # Return sampled k-mers as torch tensor
        return torch.stack(samp_kmers)

    def log_prob(self,value):

        # Add up to obtain log_p
        log_p = torch.zeros((self.gamma.shape[-2],))
        for i in range(self.gamma.shape[-2]):

            # Get idx (there should only be one match)
            idx = torch.where(torch.all(value[i] == self.supp, dim=1))[0]

            # Add to log_p
            log_p[i] += torch.log(self.gamma[i,idx[0]]) if len(idx)>0 else torch.tensor(-1.e-20)

        return log_p

    def expand(self, batch_shape, _instance=None):

        new = self._get_checked_instance(CategAtoms, _instance)

        batch_shape = broadcast_shape(batch_shape)

        # Register class parameters
        new.supp = self.supp
        new.len_supp = self.len_supp
        new.gamma = self.gamma.expand((batch_shape[-1],self.gamma.shape[-1]))

        super(CategAtoms, new).__init__(batch_shape, self.event_shape, validate_args=False)
        new._validate_args = self._validate_args

        return new

# DPKM class
class DpkmModel:

    """
    Dirichlet process k-mer mixture model. Models the unobserved latent k-mers as a Dirichlet
    process.
    """

    def __init__(self, data, t=10, alpha=1.e1, n_iter=10000, learn_rate=0.05, noise_level=0.1):

        # Data related fields
        self.data = data                            # observed data as torch tensor uint8
        self.n = data.shape[-2]                     # number of observations
        self.k = data.shape[-1] // 2                # k-mer size
        self.supp = data.unique(dim=-2)             # support of latent k-mer space
        self.batch_size = min(self.n,100)           # batch size

        # TODO: augment support
        self.len_supp = len(self.supp)

        # Define other fields
        self.t = t                                  # maximum number of latent k-mers
        self.alpha = alpha                          # concentration parameter
        self.n_iter = n_iter                        # number of iterations
        self.learn_rate = learn_rate                # learning rate in SGD
        self.noise_level = noise_level              # noise level (emission probabilities)

        # Initialize model output
        self.losses = []                            # loss function at each iteration
        self.lat_kmers = None                       # latent k-mers detected
        self.phi_optimal = None                     # optimal phi (posterior categorical distribution)
        self.kappa_optimal = None                   # optimal kappa (posterior of stick breaking process)
        self.gamma_optimal = None                   # optimal gamma (posterior of latent k-mer composition)
        self.bayes_weights = None                   # mixture model weights

    def model(self):

        # Parameter prior on nucleotide composition of latent k-mers
        gamma = Dirichlet(1./self.len_supp * torch.ones(self.len_supp)).sample([self.t])

        # Sample betas from stick breaking process
        with pyro.plate("beta_plate", self.t-1):
            beta = pyro.sample("beta", Beta(1, self.alpha))
            # print(f"beta.shape={beta.shape}")
            # assert beta.shape == (T-1,)

        # Sample nucleotide composition of latent k-mers from a Bernoulli
        # with pyro.plate("true_flank_plate_T", T, dim=-2):
        #     with pyro.plate("true_flank_plate_2K", 2*K, dim=-1):
        #         true_flank = pyro.sample("true_flank", Bernoulli(0.5))

        # Sample latent k-mers from categorical with flat parameters
        with pyro.plate("true_flank_plate_T", self.t):
            true_flank = pyro.sample("true_flank", CategAtoms(gamma, self.supp))

        # Sample k-mer label and match to observed k-mer
        with pyro.plate("data_z", self.n, subsample_size=self.batch_size, dim=-1) as ind:

            z = pyro.sample("z", Categorical(mix_weights(beta)))
            # print(f"z.shape={z.shape}")
            # assert z.shape == (BATCH_SIZE,)

            with pyro.plate("data_obs", 2*self.k, dim=-2):
                x = pyro.sample("obs", KmerNoiseDist(true_flank[z],self.noise_level), obs=self.data.index_select(0, ind))
                # print(f"x.shape={x.shape}")
                # assert x.shape == (BATCH_SIZE,2*K)

    def guide(self):

        # Random init of posterior concentration parameter for stick-breaking process
        kappa = pyro.param('kappa', lambda: Uniform(0, 2).sample([self.t-1]), constraint=constraints.positive)
        # print(f"kappa.shape={kappa.shape}")
        # assert kappa.shape == (self.t-1,)

        # Random init of posterior categorical distribution
        phi = pyro.param('phi', lambda: Dirichlet(1./self.t * torch.ones(self.t)).sample([self.batch_size]), constraint=constraints.simplex)
        # print(f"phi.shape={phi.shape}")
        # assert phi.shape == (self.batch_size, self.t)

        # Random init of posterior of latent k-mer composition in binary representation
        gamma = pyro.param('gamma', lambda: Dirichlet(1./self.len_supp * torch.ones(self.len_supp)).sample([self.t]), constraint=constraints.simplex)
        # gamma = pyro.param('gamma', lambda: Beta(1. * torch.ones(2*self.k),1. * torch.ones(2*self.k)).sample([self.t]), constraint=constraints.unit_interval)
        # print(f"gamma.shape={gamma.shape}")
        # assert gamma.shape == (self.t,2*self.k)

        # Sample betas from beta posterior
        with pyro.plate("beta_plate", self.t-1):
            q_beta = pyro.sample("beta", Beta(torch.ones(self.t-1), kappa))
            # print(f"q_beta.shape={q_beta.shape}")
            # assert q_beta.shape == (self.t-1,)

            # Sample latent k-mer nucleotide composition from Bernoulli posterior
            # with pyro.plate("true_flank_plate_T", self.t, dim=-2):
            #     with pyro.plate("true_flank_plate_2K", 2*self.k, dim=-1):
            #         q_true_flank = pyro.sample("true_flank", Bernoulli(gamma))

        # Sample latent k-mer nucleotide composition from custom posterior distribution
        with pyro.plate("true_flank_plate_T", self.t):
            q_true_flank = pyro.sample("true_flank", CategAtoms(gamma,self.supp))
            # print(f"q_true_flank.shape={q_true_flank.shape}")
            # assert q_true_flank.shape == (self.t,2*self.k)

        # Sample latent k-mer identity z from posterior categorical over set of latent k-mers
        with pyro.plate("data_z", self.n, subsample_size=self.batch_size):
            z = pyro.sample("z", Categorical(phi))
            # print(f"z.shape={z.shape}")
            # assert z.shape == (self.batch_size,)

    # Train function
    def train(self):

        # Clean up
        pyro.clear_param_store()

        # Define optimization parameters
        optim = Adam({"lr": self.learn_rate})

        # Define SVI module
        svi = SVI(self.model, self.guide, optim, loss=TraceGraph_ELBO())

        # Iterate
        for _ in tqdm(range(self.n_iter)):

            # TODO: early stopping?
            loss = svi.step()
            self.losses.append(loss)

        # Store final variational parameters
        self.phi_optimal = pyro.param("phi").detach()
        self.gamma_optimal = pyro.param("gamma").detach()
        self.kappa_optimal = pyro.param("kappa").detach()

    # MAP estimates of hidden k-mers (Bernoulli)
    def map_lat_kmer_of_seq(self):

        self.lat_kmers = self.supp[torch.argmax(self.gamma_optimal, dim=-1)]

    # Consolidation of results
    def cons_res(self):

        seq = []
        mix = []
        uniq_flanks = unique(self.lat_kmers)

        # Loop over latent k-mers
        for f in uniq_flanks:
            seq.append(f)
            idx = [i for i,val in enumerate(self.lat_kmers) if val==f]
            mix.append(sum([self.bayes_weights[i] for i in idx]))

        # Register
        self.lat_kmers = seq
        self.bayes_weights = mix

# Stick-breaking function
def mix_weights(beta):
    beta1m_cumprod = (1 - beta).cumprod(-1)
    return F.pad(beta, (0, 1), value=1) * F.pad(beta1m_cumprod, (1, 0), value=1)

# Simulation function
def sim_data(k, n, true_latent_kmers, noise_level):

    # Encode k-mers
    true_latent_kmers_bin = torch.stack([enc_seq(x) for x in true_latent_kmers])

    # Generate
    with pyro.plate("sim_data_z", n, dim=-1):
        sim_z = pyro.sample("sim_z", Categorical(1/len(true_latent_kmers_bin) * torch.ones(len(true_latent_kmers_bin))))
        with pyro.plate("sim_data_obs", 2*k, dim=-2):
            sim_obs = pyro.sample("sim_obs", KmerNoiseDist(true_latent_kmers_bin[sim_z],noise_level))

    return sim_z,sim_obs

# Decode binary represntation of k-mer
def dec_seq(x):

    y = ''
    for i in range(0,len(x),2):
        if x[i]==0 and x[i+1]==0:
            y = y + 'A'
        elif x[i]==0 and x[i+1]==1:
            y = y + 'C'
        elif x[i]==1 and x[i+1]==0:
            y = y + 'G'
        else:
            y = y + 'T'

    return y

# Encode binary representation of k-mer
def enc_seq(y):

    x = [0] * (2*len(y))
    for i in range(len(y)):
        j = 2 * i
        if y[i]=='A':
            x[j]=0
            x[j+1]=0
        elif y[i]=='C':
            x[j]=0
            x[j+1]=1
        elif y[i]=='G':
            x[j]=1
            x[j+1]=0
        else:
            x[j]=1
            x[j+1]=1

    return torch.tensor(x,dtype=torch.uint8)
