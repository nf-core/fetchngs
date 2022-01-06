#!/usr/bin/env python

import gzip
import argparse
import pandas as pd

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--anchors_annot",
        type=str,
        help='input anchor file from dgmfinder'
    )
    parser.add_argument(
        "--signif_anchors_file",
        type=str,
        help='output file'
    )
    parser.add_argument(
        "--direction",
        type=str,
        help='up or down'
    )
    parser.add_argument(
        "--q_val",
        type=float,
        help='minimum q_val for significance'
    )
    args = parser.parse_args()
    return args


def main():
    args = get_args()

    # get q_val and anchor column, depending on what direction
    q_val_col = f'QVAL_{args.direction.upper()}'
    anchor_col = f'MAX_ANCHOR_{args.direction.upper()}'

    # read in anchors_anot file
    df = pd.read_csv(
        args.anchors_annot,
        sep='\t',
        usecols=[q_val_col, anchor_col]
    )

    # only keep anchors with a required q_val
    df = df[df[q_val_col] < args.q_val][anchor_col]

    # write out list of anchors with required q_val
    df.to_csv(
        args.signif_anchors_file,
        sep='\t',
        index=False,
        header=None
    )


if __name__ == '__main__':
    main()
