#!/usr/bin/env python

import gzip
import argparse
import pandas as pd
import numpy as np

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


def get_hits_col(row):
    if pd.isna(row['min_eval_name']):
        return np.nan
    else:
        hits_col = row['min_eval_name'].replace(
            'evalue',
            'hit'
        )
        return row[hits_col]


def main():
    args = get_args()

    # get column suffix
    if args.direction == 'down':
        suffix = 'dn'
    elif args.direction == 'up':
        suffix = 'up'

    eval_string = f'evalue_{suffix}'
    q_val_col = f'QVAL_{suffix.upper()}'
    anchor_col = f'MAX_ANCHOR_{suffix.upper()}'

    # read in anchors_anot file
    df = pd.read_csv(
        args.anchors_annot,
        sep='\t'
    )

    # get cols of min evalue
    cols = [col for col in df.columns if eval_string in col]

    if len(cols) == 0:
        df = df[df[q_val_col] < args.q_val][[anchor_col, anchor_col]]
    else:
        df['min_eval_name'] = df[cols].idxmin(axis=1)
        df['min_eval'] = df[cols].min(axis=1)
        df['min_eval_hit'] = df.apply(get_hits_col, axis=1)

        # only keep anchors with a required q_val
        df = df[df[q_val_col] < args.q_val][[anchor_col, anchor_col, 'min_eval_hit', 'min_eval']]

    # write out list of anchors with required q_val
    df.to_csv(
        args.signif_anchors_file,
        sep='\t',
        index=False,
        header=None
    )


if __name__ == '__main__':
    main()
