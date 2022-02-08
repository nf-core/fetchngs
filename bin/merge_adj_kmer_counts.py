#!/usr/bin/env python

import gzip
import argparse
import pandas as pd
from Bio import SeqIO
import numpy as np


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

    i = 0
    out_df = pd.read_csv(df_paths[0].strip(), sep='\t')
    for df_path in df_paths[1:]:
        try:
            df = pd.read_csv(df_path.strip(), sep='\t')
            out_df = out_df.merge(
                df,
                on=['anchor', 'adj_kmer'],
                how='outer'
            )
            del(df)
            # if i % 100 == 0:
            #     print(i)
            print(i)
            i += 1
        except pd.errors.EmptyDataError:
            print('empty')


    out_df = out_df.fillna(0)

    signif_anchors = (
        pd.read_csv(
            args.signif_anchors,
            sep='\t'
        )
        .drop(
            ['cluster'],
            axis=1
        )
        .drop_duplicates()
    )


    if len(signif_anchors.columns) == 3:
        signif_anchors.columns = ['anchor', 'ann_fasta', 'evalue']
    else:
        signif_anchors.columns = ['anchor']
        signif_anchors['ann_fasta'] = np.nan
        signif_anchors['evalue'] = np.nan

    out_df.to_csv(
        'test_out.txt',
        index=False,
        sep='\t'
    )

    out_df = (
        signif_anchors
            .merge(
                out_df,
                on='anchor',
            )
            .drop_duplicates()
    )
    out_df.to_csv(
        args.outfile,
        index=False,
        sep='\t'
    )


if __name__ == '__main__':
    main()
