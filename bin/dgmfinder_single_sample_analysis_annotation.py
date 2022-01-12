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
    parser.add_argument(
        "--anchors_annot",
        type=str,
        help='input fasta file'
    )

    args = parser.parse_args()
    return args


def main():
    args = get_args()

    with open(args.ann_file) as file:
        fasta_list = file.readlines()
        fasta_list = [line.rstrip() for line in fasta_list]

    anchorfile = args.anchors_annot
    config = bio.Config(annot_fasta=fasta_list)

    bio.dgmfinder_single_sample_analysis_annotation(anchorfile, config)


main()
