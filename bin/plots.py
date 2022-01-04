#!/usr/bin/env python

import gzip
import utils
import matplotlib.pyplot as plt

"""
Plots histogram Hamming distances.
"""
def plt_histo(infile,outfile):

    # Loop over file
    x = []
    with gzip.open(infile,'r') as fin:
        for line in fin:
            # Decode line
            line = line.decode('utf8')
            # Split tabs
            line_arr = line.split('\t')
            # Get actual distance
            x.append(float(line_arr[2].strip('\n')))

    # Plot
    plt.figure(figsize=(8,6))
    plt.hist(x, bins=100, alpha=0.5, label="")
    plt.xlabel("Hamming distance", size=14)
    plt.ylabel("Count", size=14)
    plt.title("Hamming distance histogram")
    plt.savefig(outfile)

    # Return nothing
    return None

"""
Plots histogram downstream vs upstream.
"""
def plt_histo_up_vs_down(infile,outfile):

    # Get dictionaries
    up,down = utils.read_table(infile)

    # Concatenate all
    x = []
    y = []
    for key in up:
        x.extend(up[key])
    for key in down:
       y.extend(down[key])

    # Plot
    plt.figure(figsize=(8,6))
    plt.hist(x, bins=100, alpha=0.5, label="upstream")
    plt.hist(y, bins=100, alpha=0.5, label="downstream")
    plt.xlabel("Hamming distance", size=14)
    plt.ylabel("Count", size=14)
    plt.title("Hamming distance histograms")
    plt.legend(loc='upper right')
    plt.savefig(outfile)

    # Return nothing
    return None
