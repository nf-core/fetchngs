#!/usr/bin/env python

import gzip
import argparse
import pandas as pd


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--samplesheet",
        type=str,
        help='input samplesheet'
    )
    parser.add_argument(
        "--num_anchors",
        help='number of anchors'
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

    signif_anchors_df = dfs[0]
    for df in dfs[1:]:
        signif_anchors_df = signif_anchors_df.append(df)

    signif_anchors_df = (
        signif_anchors_df
            .drop_duplicates()
            .sort_values(
                'cluster',
                ascending=False
            )
    )

    if args.num_anchors != "none":
        signif_anchors_df = signif_anchors_df.head(int(args.num_anchors))

    signif_anchors_df.to_csv(
        args.outfile,
        index=False,
        sep='\t'
    )


if __name__ == '__main__':
    main()
