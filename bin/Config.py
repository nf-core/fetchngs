#!/usr/bin/env python

import io
import pandas as pd

# class for configuration
class Config:

    """
    Class for configuration object.
    """

    def __init__(self, kmer_size=31, rand_lkp=False, dist=0, min_smp_sz=20, max_smp_sz=50,
                 lmer_size=7, jsthrsh=0.05, q_thresh=0.1, batch_sz_poibin=10000, max_fastq_reads=0, annot_fasta=[], name='run'):

        self.dist = dist                                    # fixed lookup distance (only matters if rand_lkp is False)
        self.jsthrsh = jsthrsh                              # jaccard similarity threshold for value collapsing
        self.q_thresh = q_thresh                            # q-value threshold
        self.rand_lkp = rand_lkp                            # true if we randomize lookup distance
        self.lmer_size = lmer_size                          # l-mer size (k-mer is divided into shorter l-mers of size l)
        self.kmer_size = kmer_size                          # k-mer analysis size
        self.max_smp_sz = max_smp_sz                        # maximum sample size required for testing
        self.min_smp_sz = min_smp_sz                        # minimum sample size required for testing
        self.annot_fasta = annot_fasta                      # array containing fasta files to use for annotation
        self.batch_sz_poibin = batch_sz_poibin              # batch size for Poisson binomial model
        self.max_fastq_reads = max_fastq_reads              # maximum number of fastq records to be processed (all if 0)
        self.name

    def report(self):

        io.print_mess("******************* CONFIGURATION *******************")
        io.print_mess(f"Maximum reads to be processed (0 means no limit): {self.max_fastq_reads}")
        io.print_mess(f"Lookahead distance: {self.dist}")
        io.print_mess(f"k-mer size: {self.kmer_size}")
        io.print_mess(f"l-mer size: {self.lmer_size}")
        io.print_mess(f"Minimum sample size: {self.min_smp_sz}")
        io.print_mess(f"Maximum sample size: {self.max_smp_sz}")
        io.print_mess(f"Jaccard similarity threshold: {self.jsthrsh}")
        io.print_mess(f"Batch size Poisson binomial null: {self.batch_sz_poibin}")
        io.print_mess(f"Q-value threshold: {self.q_thresh}")
        io.print_mess("********************* ANALYSIS **********************")

        outfile = f"{self.outdir}/{self.name}"

        report = {
            'max_fastq_reads': [self.max_fastq_reads],
            'lookahead_distance': [self.dist],
            'kmer_size': [self.kmer_size],
            'lmer_size': [self.lmer_size],
            'min_sample_size': [self.min_smp_sz],
            'max_sample_size': [self.max_smp_sz],
            'Jaccard_similarity_threshold': [self.jsthrsh],
            'batch_size_Poisson_binomial_null': [self.batch_sz_poibin],
            'Q_value_threshold': [self.q_thresh]
        }

        pd.DataFrame(report).to_csv(
            outfile,
            sep='\t',
            index=False
        )
