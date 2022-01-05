#!/usr/bin/env python

import argparse
import gzip
import bio
from Config import Config
import logging

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ann_file",
        type=str,
        help='list of annotation fastq files'
    )
    parser.add_argument("--fastq_file",
        type=str,
        help='input fasta file'
    )
    parser.add_argument("--fastq_id",
        type=str,
        help='fastq id name'
    )
    parser.add_argument("--kmer_size",
        type=int,
        help='size of kmer'
    )
    args = parser.parse_args()
    return args


def main():
    args = get_args()

    logging.basicConfig(
        filename = f'{args.fastq_id}.log',
        format='%(asctime)s %(levelname)-8s %(message)s',
        level=logging.INFO,
        filemode='w',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    with open(args.ann_file) as file:
        fasta_list = file.readlines()
        fasta_list = [line.rstrip() for line in fasta_list]

    with gzip.open(args.fastq_file, 'rt') as handle:
        head = [next(handle) for x in range(2)]
        read_len = len(head[1].strip())
        distance = (read_len - 2 * args.kmer_size) / 2

    logging.info(f'============INPUTS============')
    logging.info(f'fastq_id         : {args.fastq_id}')
    logging.info(f'fastq_file       : {args.fastq_file}')
    logging.info(f'ann_file         : {args.ann_file}')
    logging.info(f'kmer_size        : {args.kmer_size}')
    logging.info(f'lookahead_dist   : {distance}')
    logging.info(f'==============================')
    logging.info('')

    # configure run
    config = Config(
        dist = distance,                # lookahead distance as a function of read length
        kmer_size=args.kmer_size,       # k-mer size used in the analysis
        min_smp_sz=5,                   # minimum sample size to compute p-value
        max_smp_sz=50,                  # maximum number of sequences sampled per
        lmer_size=7,                    # l-mer size used to compute jaccard similarity between k-mers
        jsthrsh=0.25,                   # jaccard similarity threshold used to collapse the observed sequences
        max_fastq_reads=5000000,        # maximum number of FASTQ reads to process
        annot_fasta=fasta_list          # array containing fasta files to use with blast
    )

    # run analysis
    bio.dgmfinder_single_sample_analysis(args.fastq_file, args.fastq_id, config)

    logging.info('Completed!')


main()
