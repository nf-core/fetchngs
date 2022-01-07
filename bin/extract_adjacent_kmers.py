#!/usr/bin/env python

import gzip
import argparse
import pandas as pd
from Bio import SeqIO

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--signif_anchors_file",
        type=str,
        help='input file of significant anchors'
    )
    parser.add_argument(
        "--fastq_file",
        type=str,
        help='input fasta file'
    )
    parser.add_argument(
        "--signif_anchors_reads_file",
        type=str,
        help='output file of reads containing significant anchors'
    )
    parser.add_argument(
        "--adjacent_anchors_file",
        type=str,
        help='output file of adjacent anchors to significant anchors'
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

    # read in significant anchors into a list
    with open(args.signif_anchors_file) as file:
        signif_anchors = file.readlines()
        signif_anchors = [line.rstrip() for line in signif_anchors]

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

    # open files for reading and writing
    with open(args.signif_anchors_reads_file, 'w') as out_reads:
        with open(args.adjacent_anchors_file, 'w') as out_anchors:
            # write out header
            out_anchors.write(f'signif_anchor\tadjacent_anchor\n')
            with gzip.open(args.fastq_file, 'rt') as fastq_reader:

                # stream fastq file and output if necessary
                for record in SeqIO.parse(fastq_reader, 'fastq'):
                    read = str(record.seq)

                    # check if read contains any significant anchors
                    if any(anchor in read for anchor in signif_anchors):
                        matching_anchors = [a for a in signif_anchors if a in read]

                        # add matching anchors to fastq id
                        matching_anchors_string = "_".join(matching_anchors)
                        record.id = f'{str(record.id)} {matching_anchors_string}'

                        # write out read to signif_anchors_reads_file
                        SeqIO.write(record, out_reads, 'fasta')

                        # for every matching anchor, extract adjacent anchor
                        for anchor in matching_anchors:
                            # get anchor position
                            anchor_end = read.index(anchor) + len(anchor)
                            # get adjacent anchor position
                            adj_anchor_start = anchor_end + adj_dist
                            adj_anchor_end = adj_anchor_start + adj_len
                            adj_anchor = read[adj_anchor_start:adj_anchor_end]
                            # write out to adjacent_anchors_file
                            out_anchors.write(f'{anchor}\t{adj_anchor}\n')


if __name__ == '__main__':
    main()
