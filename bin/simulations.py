#!/usr/bin/env python

import numpy as np
import Config
from dgmfinder import bio, jaccard, poibin

# class reference only for these simulations
class AnchorKmerSims:

    """
    Class for each reference k-mer.
    """

    def __init__(self, dna):
        self.dna = dna                                      # dna sequence
        self.up_done = False                                # done accepting upstream sequences
        self.dn_done = False                                # done accepting downstream sequences
        self.up_lkp_d = None                                # lookup distance upstream
        self.dn_lkp_d = None                                # lookup distance downstream
        self.up_cnt = np.uint16(0)                          # number of instances upstream
        self.dn_cnt = np.uint16(0)                          # number of instances downstream
        self.up_dict = {}                                   # dictionary of k-mers observed upstream
        self.dn_dict = {}                                   # dictionary of k-mers observed downstream
        self.up_olap_hvr = False                            # boolean showing whether up k-mer overlaps with hvr
        self.dn_olap_hvr = False                            # boolean showing whether dn k-mer overlaps with hvr
        self.up_c_seq = []                                  # sequence of c for up k-mer
        self.up_n_seq = []                                  # sequence of n for up k-mer
        self.up_x_seq = []                                  # sequence Xn for up k-mer
        self.dn_c_seq = []                                  # sequence of c for dn k-mer
        self.dn_n_seq = []                                  # sequence of n for dn k-mer
        self.dn_x_seq = []                                  # sequence Xn for dn k-mer
        self.up_log_fc = np.nan
        self.dn_log_fc = np.nan
        self.up_pval = np.nan
        self.dn_pval = np.nan
        self.up_qval = np.nan
        self.dn_qval = np.nan

    # for printing structure
    def __str__(self) -> str:
        return f"""
        dna: {self.dna}
        up_dict: {self.up_dict}
        up_x_seq: {self.up_x_seq}
        up_c_seq: {self.up_c_seq}
        up_n_seq: {self.up_n_seq}
        up_log_fc: {self.up_log_fc}
        up_pval: {self.up_pval}
        up_qval: {self.up_qval}
        up_olap_hvr: {self.up_olap_hvr}
        dn_dict: {self.dn_dict}
        dn_x_seq: {self.dn_x_seq}
        dn_c_seq: {self.dn_c_seq}
        dn_n_seq: {self.dn_n_seq}
        dn_log_fc: {self.dn_log_fc}
        dn_pval: {self.dn_pval}
        dn_qval: {self.dn_qval}
        dn_olap_hvr: {self.dn_olap_hvr}
        """

    # computes poisson binomial p-values
    def comp_anchor_poibin_pval(self, pnvec, n_min):

        """
        Computes Poisson binomial of both pairs (anchor,up) and (anchor,dn).
        """

        if self.up_cnt>n_min:
            k = np.minimum(len(self.up_x_seq), len(pnvec))
            pb = poibin.PoiBin(pnvec[:k])
            obs_c = sum(self.up_x_seq[:k])
            self.up_log_fc = np.log(obs_c)-np.log(sum(pnvec[:k]))
            self.up_pval = np.maximum(pb.pval(obs_c),np.finfo(float).eps)
            # print(f"obs_c={obs_c}; up_pval={self.up_pval}; up_log_fc={self.up_log_fc} ")
        else:
            self.up_pval = np.nan
            self.up_log_fc = np.nan

        if self.dn_cnt>n_min:
            k = np.minimum(len(self.dn_x_seq), len(pnvec))
            pb = poibin.PoiBin(pnvec[:k])
            obs_c = sum(self.dn_x_seq[:k])
            self.dn_log_fc = np.log(obs_c)-np.log(sum(pnvec[:k]))
            self.dn_pval = np.maximum(pb.pval(obs_c),np.finfo(float).eps)
            # print(f"obs_c={obs_c}; up_pval={self.dn_pval}; up_log_fc={self.dn_log_fc} ")
        else:
            self.dn_pval = np.nan
            self.dn_log_fc = np.nan

# generates random dna sequence
def ran_dna_seq(k):
    """
    Generates random sequence of length k.
    """
    return ''.join(np.random.choice(list('ACTG')) for _ in range(k))

# simulates num_gnm genomes from single species of length gnm_len with one HVR
def sim_gnms_sngl_species(num_gnm, gnm_len, hvr_len):

    """
    Simulates `num_gnm` genomes from single species of length `gnm_len` with one HVR of length `hvr_len`.
    The genomes only differ in the HVR.
    """

    # sample random sequence of length gnm_len
    gnm_bse = ran_dna_seq(gnm_len)

    # sample num_gnm random hvr
    hvr_seq = [ran_dna_seq(hvr_len) for _ in range(num_gnm)]

    # locate hvr in middle of genome
    hvr_pos = (gnm_len - hvr_len)//2

    # insert hvr
    gnmes = []
    for i in range(num_gnm):
        gnmes.append(gnm_bse[:hvr_pos] + hvr_seq[i] + gnm_bse[(hvr_pos+hvr_len):])

    # returns set of genomes
    return gnmes, range(hvr_pos, hvr_pos+hvr_len)

# perturbates a read
def mod_kmer(kmer, sigma):

    """
    Introduces random substitutions and indels to a read.
    """

    k = len(kmer)

    for i in range(k):

        if np.random.uniform()>1.0-sigma:

            if np.random.uniform()>0.5:

                # indel
                if np.random.uniform()>0.5:
                    # insertion
                    # print("insertion")
                    kmer = kmer[:i] + np.random.choice(list(set('ACTG'))) + kmer[i:-1]
                else:
                    # deletion
                    # print("deletion")
                    kmer = kmer[:i] + kmer[(i+1):] + np.random.choice(list(set('ACTG')))
            else:

                # substitution
                # print("substitution")
                bse = set(kmer[i])
                kmer = kmer[:i] + np.random.choice(list(set('ACTG')-bse)) + kmer[(i+1):]

    return kmer

# sample reads from genomes
def samp_reads(gnms, rd_len, num_rds, sigma=0.05):

    """
    Returns `num_rds` of size `rd_len` frin a set of genomes `gnms`.
    """

    # init
    rds = []
    pos = []

    # sample num_rds gnm_id
    gnm_ids = np.random.choice(range(len(gnms)), size=num_rds)

    # sample position of reads
    for i in range(len(gnms)):

        # get indices of reads coming from i-th genome
        gnm_msk = gnm_ids == i

        # sample x positions
        x = np.trunc(np.random.uniform(high=len(gnms[i])-rd_len, size=sum(gnm_msk))).astype(int)
        pos.extend(x)

        # add noise to reads
        x = [mod_kmer(gnms[i][x[j]:(x[j]+rd_len)], sigma) for j in range(len(x))]

        # store reads
        rds.extend(x)

    # return reads
    return gnm_ids, rds, pos

def overlap(x, y):

    return range(max(x.start,y.start), min(x.stop,y.stop)) or None

# pre-processes reads
def preproc_rds(rds, pos, hvr_rng, kmer_size, lmer_sze, rand_lkp=False, min_smp_sz=5, max_smp_sz=50, dist=1, jsthrsh=0.02, quiet=False):

    """
    Returns dictionary of AnchorKmerSims objects.
    """

    # init dictionary
    seq_dct = {}

    # get total num of reads
    n_now = 0
    n_tot = len(rds)

    # oracle?
    # min_p = min_smp_sz/n_tot
    # no_new_kmers = False

    # loop over sequences
    for read_ind, read_seq in enumerate(rds):

        # loop over sequence
        i = 0
        while (i+kmer_size)<=len(read_seq):

            ## take care of reference k-mer

            # get reference k-mer
            ref_kmer = read_seq[i:(i+kmer_size)]
            read_rng = range(pos[read_ind], pos[read_ind]+len(read_seq))

            # create entry in dictionary if it doesn't exist if worth it
            if ref_kmer not in seq_dct:

                # # Check if accepting new k-mers at all
                # if no_new_kmers:

                #     # Increase counter so we move on and continue
                #     i += 1
                #     continue

                # accept k-mer if still fair game
                seq_dct[ref_kmer] = AnchorKmerSims(ref_kmer)

                # sample lookup distance if necessary
                up_lkp_d = np.random.choice(range(1,kmer_size)) if rand_lkp else dist
                dn_lkp_d = np.random.choice(range(1,kmer_size)) if rand_lkp else dist
                seq_dct[ref_kmer].up_lkp_d = up_lkp_d
                seq_dct[ref_kmer].dn_lkp_d = dn_lkp_d

                # get ranges
                up_kmer_abs_rng = range(pos[read_ind]+i-kmer_size-up_lkp_d, pos[read_ind]+i-up_lkp_d)
                up_kmer_abs_rng = overlap(read_rng, up_kmer_abs_rng)
                dn_kmer_abs_rng = range(pos[read_ind]+i+kmer_size+dn_lkp_d, pos[read_ind]+i+2*kmer_size+dn_lkp_d)
                dn_kmer_abs_rng = overlap(read_rng, dn_kmer_abs_rng)

                # check if it overlaps hrv
                seq_dct[ref_kmer].up_olap_hvr = False
                seq_dct[ref_kmer].dn_olap_hvr = False
                if up_kmer_abs_rng!=None and overlap(up_kmer_abs_rng, hvr_rng)!=None and len(overlap(up_kmer_abs_rng, hvr_rng))>3:
                    seq_dct[ref_kmer].up_olap_hvr = True
                if dn_kmer_abs_rng!=None and overlap(dn_kmer_abs_rng, hvr_rng)!=None and len(overlap(dn_kmer_abs_rng, hvr_rng))>3:
                    seq_dct[ref_kmer].dn_olap_hvr = True

            ## check flanking k-mers at distance dist

            # get upstream candidate variable sequence
            if not seq_dct[ref_kmer].up_done and (i-(seq_dct[ref_kmer].up_lkp_d+kmer_size-1))>=0:

                # get upstream sequence
                up_kmer = read_seq[(i-(seq_dct[ref_kmer].up_lkp_d+kmer_size-1)):(i-seq_dct[ref_kmer].up_lkp_d+1)]

                # register variable upstream k-mer
                seq_dct[ref_kmer].up_cnt += 1
                xn = jaccard.add_new_val_js(seq_dct[ref_kmer].up_dict, up_kmer, lmer_sze, jsthrsh)

                # update sequences
                seq_dct[ref_kmer].up_n_seq.append(seq_dct[ref_kmer].up_cnt)
                seq_dct[ref_kmer].up_c_seq.append(len(list(seq_dct[ref_kmer].up_dict)))
                if seq_dct[ref_kmer].up_cnt == 1:
                    seq_dct[ref_kmer].up_x_seq.append(1)
                else:
                    seq_dct[ref_kmer].up_x_seq.append(seq_dct[ref_kmer].up_c_seq[-1]-seq_dct[ref_kmer].up_c_seq[-2])

                # check if done
                seq_dct[ref_kmer].up_done = True if seq_dct[ref_kmer].up_cnt>=max_smp_sz else False

            # get downstream candidate variable sequence
            if not seq_dct[ref_kmer].dn_done and (i+2*kmer_size+seq_dct[ref_kmer].dn_lkp_d-1)<=len(read_seq):

                # get downstream sequence
                dn_kmer = read_seq[(i+kmer_size+seq_dct[ref_kmer].dn_lkp_d-1):(i+2*kmer_size+seq_dct[ref_kmer].dn_lkp_d-1)]

                # register variable downstream k-mer
                seq_dct[ref_kmer].dn_cnt += 1
                jaccard.add_new_val_js(seq_dct[ref_kmer].dn_dict, dn_kmer, lmer_sze, jsthrsh)

                # update sequences
                seq_dct[ref_kmer].dn_n_seq.append(seq_dct[ref_kmer].dn_cnt)
                seq_dct[ref_kmer].dn_c_seq.append(len(list(seq_dct[ref_kmer].dn_dict)))
                if seq_dct[ref_kmer].dn_cnt == 1:
                    seq_dct[ref_kmer].dn_x_seq.append(1)
                else:
                    seq_dct[ref_kmer].dn_x_seq.append(seq_dct[ref_kmer].dn_c_seq[-1]-seq_dct[ref_kmer].dn_c_seq[-2])

                # check if done
                seq_dct[ref_kmer].dn_done = True if seq_dct[ref_kmer].dn_cnt>=max_smp_sz else False

            # shift reference k-mer one position
            i += 1

            # shift reference k-mer k positions
            # i += kmer_size

        # report progress
        n_now += 1
        if not quiet and n_now%100==0:
            prog = n_now/n_tot*100
            print(f"{prog}%")

    # return dictionary
    return seq_dct
