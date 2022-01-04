#!/usr/bin/env python

import numpy as np
import poibin

# class for anchor k-mer during processing
class AnchorKmer:

    """
    Class for each anchor k-mer.
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
        self.up_x_seq = []                                  # sequence Xn for up k-mer
        self.dn_x_seq = []                                  # sequence Xn for dn k-mer
        self.up_log_fc = np.nan                             # log-fold change up k-mer
        self.dn_log_fc = np.nan                             # log-fold change dn k-mer
        self.up_pval = np.nan                               # p-value up k-mer
        self.dn_pval = np.nan                               # p-value dn k-mer
        self.up_qval = np.nan                               # q-value up k-mer
        self.dn_qval = np.nan                               # q-value dn k-mer

    # when printing
    def __str__(self) -> str:

        return f"""
        dna: {self.dna}
        up_dict: {self.up_dict}
        up_x_seq: {self.up_x_seq}
        up_log_fc: {self.up_log_fc}
        up_pval: {self.up_pval}
        up_qval: {self.up_qval}
        dn_dict: {self.dn_dict}
        dn_x_seq: {self.dn_x_seq}
        dn_log_fc: {self.dn_log_fc}
        dn_pval: {self.dn_pval}
        dn_qval: {self.dn_qval}
        """

    # computes poisson binomial p-values
    def comp_anchor_poibin_pval(self, pnvec, n_min):

        """
        Computes Poisson binomial of both pairs (anchor,up) and (anchor,dn).
        """

        # test counter
        m = 0

        # upstream
        if self.up_cnt>n_min:
            k = np.minimum(len(self.up_x_seq), len(pnvec))
            pb = poibin.PoiBin(pnvec[:k])
            obs_c = sum(self.up_x_seq[:k])
            self.up_log_fc = np.log2(obs_c)-np.log2(sum(pnvec[:k]))
            self.up_pval = np.maximum(pb.pval(obs_c),np.finfo(float).eps)
            # print(f"obs_c={obs_c}; up_pval={self.up_pval}; up_log_fc={self.up_log_fc} ")
            m += 1

        # downstream
        if self.dn_cnt>n_min:
            k = np.minimum(len(self.dn_x_seq), len(pnvec))
            pb = poibin.PoiBin(pnvec[:k])
            obs_c = sum(self.dn_x_seq[:k])
            self.dn_log_fc = np.log2(obs_c)-np.log2(sum(pnvec[:k]))
            self.dn_pval = np.maximum(pb.pval(obs_c),np.finfo(float).eps)
            # print(f"obs_c={obs_c}; up_pval={self.dn_pval}; up_log_fc={self.dn_log_fc} ")
            m += 1

        # return number of tests
        return m
