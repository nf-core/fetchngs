#!/usr/bin/env python

import gzip
import argparse
import pandas as pd
from Bio import SeqIO
import pandas as pd


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--samplesheet",
        type=str,
        help='input samplesheet'
    )
    parser.add_argument(
        "--signif_anchors",
        type=str,
        help='input file of significant anchors'
    )
    parser.add_argument(
        "--outfile",
        type=str,
        help='input file of significant anchors'
    )
    args = parser.parse_args()
    return args


def main():
    args = get_args()

    # read in all the dfs
    with open(args.samplesheet) as file:
        df_paths = file.readlines()

    dfs = []
    for df_path in df_paths:
        df = pd.read_csv(df_path.strip(), sep='\t')
        dfs.append(df)

    out_df = dfs[0]
    for df in dfs[1:]:
        out_df = out_df.merge(
            df,
            on=['anchor', 'adj_kmer']
        )

    signif_anchors = pd.read_csv(
        args.signif_anchors,
        sep='\t'
    )
    signif_anchors.columns = ['anchor', 'ann_fasta', 'evalue']

    out_df = out_df.merge(
        signif_anchors,
        on='anchor',
        how='inner'

    )

    out_df.to_csv(
        args.outfile,
        index=False,
        sep='\t'
    )


if __name__ == '__main__':
    main()
