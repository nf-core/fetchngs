#!/usr/bin/env python

import gzip
import argparse
import pandas as pd
from Bio import SeqIO
import pandas as pd


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--num_input_lines",
        type=int,
        help='max number of fastq reads for input'
    )
    parser.add_argument(
        "--adj_kmers_file",
        type=str,
        help='input file of significant anchors'
    )
    parser.add_argument(
        "--fastq_file",
        type=str,
        help='input fasta file'
    )
    parser.add_argument("--fastq_id",
        type=str,
        help='fastq id name'
    )
    parser.add_argument(
        "--out_signif_anchors_fasta",
        type=str,
        help='output file of reads containing significant anchors'
    )
    parser.add_argument(
        "--out_adj_kmer_counts_file",
        type=str,
        help='output file of reads containing significant anchors'
    )
    parser.add_argument(
        "--kmer_size",
        type=int,
        nargs='?',
        help='kmer size'
    )
    parser.add_argument(
        "--adj_dist",
        type=int,
        nargs='?',
        help='distance of adjacent anchor'
    )
    parser.add_argument(
        "--adj_len",
        type=int,
        nargs='?',
        help='length of adjacent anchor'
    )
    args = parser.parse_args()
    return args


def main():
    args = get_args()

    # read in anchors and adj_kmers
    anchor_df = (
        pd.read_csv(
            args.adj_kmers_file,
            sep='\t'
        )
        .drop_duplicates()
        .sort_values(by='index')
    )

    anchor_df.columns = ['anchor', 'adj_kmer']

    # remove any anchors that contain more than 10 same consecutive bases
    kmer_blacklist = [
        'A' * 10,
        'C' * 10,
        'G' * 10,
        'T' * 10
    ]
    anchor_df = anchor_df[~anchor_df['anchor'].str.contains('|'.join(kmer_blacklist))]

    anchor_df['seq_tuple'] = list(zip(anchor_df['anchor'], anchor_df['adj_kmer']))

    # create counts_dict for counting
    counts_dict = dict([(key, 0) for key in anchor_df['seq_tuple']])

    # if adj_dist is not provided, use lookahead distance
    if args.adj_dist is None:
        with gzip.open(args.fastq_file, 'rt') as reader:
            head = [next(reader) for x in range(2)]

        read_len = len(head[1].strip())
        distance = int((read_len - 2 * args.kmer_size) / 2)

        adj_dist = distance
    else:
        adj_dist = args.adj_dist

    # if adj_len is not provided, use kmer_size
    if args.adj_len is None:
        adj_len = args.kmer_size
    else:
        adj_len = args.adj_len

    ## Parse fastq file
    # open files for reading and writing
    with open(args.out_signif_anchors_fasta, 'w') as out_reads:
        with gzip.open(args.fastq_file, 'rt') as fastq_reader:

            read_counter = 0
                # stream fastq file and output if necessary
                for record in SeqIO.parse(fastq_reader, 'fastq'):
                    while read_counter < args.num_input_lines:
                        read = str(record.seq)

                        # check if read contains any significant anchors
                        if any(anchor_tuple[0] in read for anchor_tuple in counts_dict.keys()):

                            # if signif anchor found in read, get tuple of (signif_anchor, adj_kmer )
                            matching_anchors = [anchor_tuple for anchor_tuple in counts_dict.keys() if anchor_tuple[0] in read]

                            ## Write out reads with any anchor to fastq
                            # get string of matching anchors i.e. 'ACGT_ACGT_ACGT'
                            # matching_anchors_string = "_".join([a[0] for a in matching_anchors])
                            # # add matching anchors to fastq id
                            # record.id = f'{str(record.id)} {matching_anchors_string}'
                            # write out read to adj_kmers file
                            SeqIO.write(record, out_reads, 'fasta')

                            ## Count occurance of anchor, adj_kmer pairs
                            # for every matching anchor, check for adj_kmer match
                            for anchor_tuple in matching_anchors:
                                # define
                                anchor = anchor_tuple[0]
                                adj_kmer = anchor_tuple[1]

                                # get anchor position
                                anchor_end = read.index(anchor) + len(anchor)
                                # get adj_kmer position
                                adj_kmer_start = anchor_end + adj_dist
                                adj_kmer_end = adj_kmer_start + adj_len
                                # check for adj_kmer match
                                if adj_kmer == read[adj_kmer_start:adj_kmer_end]:
                                    # update counts
                                    counts_dict[anchor_tuple] += 1
                        read_counter += 1

    # reformat and write out
    counts_df = (
        pd.DataFrame.from_dict(
            counts_dict,
            orient='index'
        )
        .reset_index()
        .dropna()
        .sort_values(['index'])
    )

    counts_df.columns = ['anchor_tuple', args.fastq_id]

    counts_df[['anchor', 'adj_kmer']] = pd.DataFrame(
        counts_df['anchor_tuple'].tolist(),
        index=counts_df.index
    )

    counts_df[['anchor', 'adj_kmer', args.fastq_id]].to_csv(
        args.out_adj_kmer_counts_file,
        index=False,
        sep='\t'
    )


if __name__ == '__main__':
    main()
