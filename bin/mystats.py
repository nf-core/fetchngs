#!/usr/bin/env python

import numpy as np
import editdistance
import utils
import debruijn
from sklearn.cluster import DBSCAN
from scipy.stats import binom, norm
from statsmodels.stats.multitest import multipletests

# returns true if worth keeping k-mer in dictionary (slow)
def kp_kmer_oracle_says_slow(x,n_so_far,n_tot,min_smp_sz,thres=0.5):

    """
    Returns true if it's worth keeping k-mer in dictionary. It computes the probability that we will
    observe the k-mer at least `min_smp_sz` times by the end of the file and returns true if this
    probability is greater than some threshold.
    """

    # Get estimate phat of success probability in read
    # phat = x/n_so_far

    # Compute probability that we will observe it at least min sample size times
    # prob = 1.0 - binom.cdf(min_smp_sz, n_tot, x/n_so_far)

    # Return true if prob>=thresh
    return 1.0-binom.cdf(min_smp_sz, n_tot, x/n_so_far) >= thres

# returns true if worth keeping k-mer in dictionary (fast)
def kp_kmer_oracle_says(x,n_so_far,n_tot,min_smp_sz,thres=0.5):

    """
    Returns true if it's worth keeping k-mer in dictionary. It computes the probability that we will
    observe the k-mer at least `min_smp_sz` times by the end of the file and returns true if this
    probability is greater than some threshold. Uses normal approximation of binomial for performance
    improvements.
    """

    # Get estimate phat of success probability in read
    phat = x/n_so_far

    # Return true if prob>=thresh (normal approximation)
    return 1.0-norm.cdf((min_smp_sz-n_tot*phat)/(np.sqrt(0.01+n_tot*phat*(1.0-phat))),0,1) >= thres

# returns cluster k-mer labels
def clust_kmers(kmers):

    """
    Returns anchor k-mer cluster (DBSCAN) labels. The Levenshtein distance is used during the clustering
    of the anchor k-mers.
    """

    # returns Levinshtein distance
    def lev_metric(x, y):
        return editdistance.eval(kmers[int(x[0])], kmers[int(y[0])])

    # Run DBSCAN (eps: radius, min_samples: min samples per cluster)
    X = np.arange(len(kmers)).reshape(-1, 1)

    try:
        dbscan_fit = DBSCAN(metric=lev_metric, eps=2, min_samples=1, n_jobs=-1).fit(X)
    except RuntimeError:
        dbscan_fit = DBSCAN(metric=lev_metric, eps=2, min_samples=1, n_jobs=1).fit(X)

    # return labels
    return dbscan_fit.labels_

# assemble all keys
def asmbl_all_keys(seq_dict, ys):

    """
    Assembles all keys in list.
    """

    # init
    kmer_stats_cllps = []
    key_lst = np.array(list(seq_dict))

    # loop over cluster labels
    for y in np.unique(ys):

        # get cluster k-mers
        seqs = key_lst[ys==y]

        # assemble keys
        seq_asmbl = debruijn.asmbl_keys(seqs)

        # assign assembled sequence if succcessful
        if len(seq_asmbl)<=len(seqs[0]):
            seq_asmbl = seqs[0]

        # get maximal pair
        max_c_up = 0
        max_c_dn = 0
        max_n_up = 0
        max_n_dn = 0
        max_qval_up = 1.0
        max_qval_dn = 1.0
        max_kmer_up = "N"
        max_kmer_dn = "N"
        max_lfc_up = -np.Inf
        max_lfc_dn = -np.Inf
        for seq in seqs:
            if seq_dict[seq].up_log_fc > max_lfc_up:
                max_kmer_up = seq
                max_qval_up = seq_dict[seq].up_qval
                max_lfc_up = seq_dict[seq].up_log_fc
                max_n_up = len(seq_dict[seq].up_x_seq)
                max_c_up = sum(seq_dict[seq].up_x_seq)
            if seq_dict[seq].dn_log_fc > max_lfc_dn:
                max_kmer_dn = seq
                max_qval_dn = seq_dict[seq].dn_qval
                max_lfc_dn = seq_dict[seq].dn_log_fc
                max_n_dn = len(seq_dict[seq].dn_x_seq)
                max_c_dn = sum(seq_dict[seq].dn_x_seq)

        # construct output line
        kmer_line = [seq_asmbl]
        kmer_line.extend([max_c_up, max_n_up, max_lfc_up, max_qval_up, max_kmer_up])
        kmer_line.extend([max_c_dn, max_n_dn, max_lfc_dn, max_qval_dn, max_kmer_dn])
        kmer_line.append(round(seq_asmbl.count('A')/len(seq_asmbl)*100,2))
        kmer_line.append(round(seq_asmbl.count('C')/len(seq_asmbl)*100,2))
        kmer_line.append(round(seq_asmbl.count('G')/len(seq_asmbl)*100,2))
        kmer_line.append(round(seq_asmbl.count('T')/len(seq_asmbl)*100,2))
        kmer_line.append(",".join(seqs))

        # add to output array
        kmer_stats_cllps.append(kmer_line)

        # delete keys in dictionary
        for seq in seqs:
            del seq_dict[seq]

    # return kmer stats
    return np.asarray(kmer_stats_cllps, dtype=object)

# collapses anchor k-mers
def cllps_anchors(seq_dict):

    """
    Collpases anchor k-mers.
    """

    utils.print_mess("Clustering and assembling anchors...")

    # Get k-mers
    kmers = list(seq_dict.keys())

    # Get cluster labels
    ys = clust_kmers(kmers)

    # Return collapsed anchors
    return asmbl_all_keys(seq_dict, ys)

# get training data
def poibin_train_data(x, y):

    """
    Randomly chooses a set of y indices from a list of size x.
    """

    utils.print_mess("Randomly choosing training data for null model...")
    # print(f'x: {x}, y: {y}')

    null_ind = np.random.uniform(low=0, high=x, size=y)
    null_ind = np.trunc(null_ind).astype(int)

    return null_ind

# fits poisson binomial model
def fit_poibin_model(seq_dct, n_max, null_ind):

    """
    Fits Poisson binomial model to `null_ind`.
    """

    utils.print_mess("Fitting Poisson binomial null model...")

    # init
    n_range = range(n_max+1)
    pnvec = np.zeros(len(n_range))
    totvec = np.ones(len(n_range))

    # iterate over keys
    for i, key in enumerate(seq_dct):

        # if in set of indices then proceed
        if i not in null_ind:
            continue

        # deal with upstream
        if seq_dct[key].up_cnt>0:
            for n_ in n_range:
                totvec[n_-1] += 1
                pnvec[n_-1] += seq_dct[key].up_x_seq[n_-1]
                if n_+1 > len(seq_dct[key].up_x_seq):
                    break

        # deal with downstream
        if seq_dct[key].dn_cnt>0:
            for n_ in n_range:
                totvec[n_-1] += 1
                pnvec[n_-1] += seq_dct[key].dn_x_seq[n_-1]
                if n_+1 > len(seq_dct[key].dn_x_seq):
                    break

    # normalize vector
    pnvec = pnvec / totvec

    # return vector
    return pnvec

# computes p-value poisson binomial
def comp_poibin_pval(seq_dct, pnvec, n_min):

    """
    Computes log-fold change and p-value under Poisson binomial null.
    """

    utils.print_mess("Computing log-fold change and p-value under Poisson binomial ...")

    # test counter
    m = 0

    # traverse data and look for
    for key in seq_dct:

        m += seq_dct[key].comp_anchor_poibin_pval(pnvec, n_min)

    # return num tests
    return m

# checks if it's worth keeping key in dictionary
def check_w_oracle(data_dict, n_so_far, n_tot, config):

    """
    Checks with oracle. Keeps only keys for which we anticipate will have enough data.
    """

    utils.print_mess("Checking with oracle...")

    # init counter
    balance = [0,0]

    # generate list of remove
    remove_list = []
    for key,v in data_dict.items():

        # get maximum amount of data up/down
        k = max(v.dn_cnt,v.up_cnt)

        # oracle decides
        if kp_kmer_oracle_says(k, n_so_far, n_tot, config.min_smp_sz):
            balance[1] += 1
            continue
        else:
            balance[0] += 1
            remove_list.append(key)

    # remove
    for key in remove_list:
        del data_dict[key]

    utils.print_mess("Discarded " + str(balance[0]) + " k-mers. Left " + str(balance[1]))

# drops non-significant anchors
def drop_p_nonsig_anchors(data_dict, q_thresh):

    utils.print_mess("Dropping non-significant anchors (p>q_thresh)...")

    # init
    n_sig = 0

    # generate list of remove
    remove_list = []
    for key,v in data_dict.items():

        # get maximum amount of data up/down
        k = max(v.dn_cnt,v.up_cnt)

        # oracle decides
        if data_dict[key].up_pval<=q_thresh or data_dict[key].dn_pval<=q_thresh:
            n_sig += 1
        else:
            remove_list.append(key)

    # remove
    for key in remove_list:
        del data_dict[key]

    # return number of significant
    return n_sig

# drops non-significant anchors
def drop_q_nonsig_anchors(data_dict, q_thresh):

    utils.print_mess("Dropping non-significant anchors (q>q_thresh)...")

    # init
    n_sig = 0

    # generate list of remove
    remove_list = []
    for key,v in data_dict.items():

        # get maximum amount of data up/down
        k = max(v.dn_cnt,v.up_cnt)

        # oracle decides
        if data_dict[key].up_qval<=q_thresh or data_dict[key].dn_qval<=q_thresh:
            n_sig += 1
        else:
            remove_list.append(key)

    # remove
    for key in remove_list:
        del data_dict[key]

    # return number of significant
    return n_sig

# multiple hypothesis correction
def poibin_mult_hyp_corr(seq_dct, n_tests):

    """
    Corrects for multiple hypothesis in p-values computed under Poisson binomial null model.
    """

    utils.print_mess("Correcting for multiple hypothesis...")

    # get raw p-values
    i_vec = []
    pval_vec = []
    up_dn_vec = []
    for i,key in enumerate(seq_dct):

        # check upstream
        if not np.isnan(seq_dct[key].up_pval):
            i_vec.append(i)
            up_dn_vec.append(True)
            pval_vec.append(seq_dct[key].up_pval)

        # check downstream
        if not np.isnan(seq_dct[key].dn_pval):
            i_vec.append(i)
            up_dn_vec.append(False)
            pval_vec.append(seq_dct[key].dn_pval)

    # convert to numpy
    i_vec = np.array(i_vec)
    pval_vec = np.array(pval_vec)
    up_dn_vec = np.array(up_dn_vec)

    # return if no p-values
    if len(pval_vec)==0:
        utils.print_mess("Zero p-values were computed")
        return seq_dct

    # get ranks
    rnks = pval_vec.argsort()
    rnks = rnks.argsort()

    # store in structure
    for i,key in enumerate(seq_dct):

        # check if key has p-value
        if i in i_vec:

            i_mask = i_vec==i
            up_indx = np.where(i_mask * (up_dn_vec))[0]
            dn_indx = np.where(i_mask * (~up_dn_vec))[0]

            if len(up_indx)>0:
                seq_dct[key].up_qval = np.minimum(1, pval_vec[up_indx[0]] * n_tests / (1+rnks[up_indx[0]]))

            if len(dn_indx)>0:
                seq_dct[key].dn_qval = np.minimum(1, pval_vec[dn_indx[0]] * n_tests / (1+rnks[dn_indx[0]]))

    # TODO: apply monotonicity correction

# run binomial modeling
def poibin_test(seq_dct, config):

    """
    Fits Poisson binomial model to subsample and records p-value and statistic.
    """

    utils.print_mess("Doing statistical test based on Poisson binomial null...")

    # get training data
    null_ind = poibin_train_data(len(seq_dct), config.batch_sz_poibin)

    # fit null model
    pnvec = fit_poibin_model(seq_dct, config.max_smp_sz, null_ind)

    # compute stats and p-value
    n_tests = comp_poibin_pval(seq_dct, pnvec, config.min_smp_sz)

    # return false if no tests
    if n_tests == 0:
        utils.print_mess("No statistical tests were performed due to lack of samples")
        return False
    else:
        utils.print_mess(f"Performed {n_tests} statistical tests...")

    # drop ones that are clearly non-significant
    n_sig = drop_p_nonsig_anchors(seq_dct, config.q_thresh)

    # return false if no significant left
    if n_sig == 0:
        utils.print_mess("No significant results found after computing p-value")
        return False
    else:
        utils.print_mess(f"Number of p-values<=qthresh: {n_sig}")

    # correct for mh
    poibin_mult_hyp_corr(seq_dct, n_tests)

    # drop non-significant ones
    n_sig = drop_q_nonsig_anchors(seq_dct, config.q_thresh)

    # return false if no significant left
    if n_sig == 0:
        utils.print_mess("No significant results found after computing q-value")
        return False
    else:
        utils.print_mess(f"Number of q-values<=qthresh: {n_sig}")

    # return true if some positives
    return True
