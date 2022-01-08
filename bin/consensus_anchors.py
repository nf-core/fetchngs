#!/usr/bin/env python

import pandas as pd
import gzip
import os
import re
import sys
import argparse
import logging
from Bio import SeqIO


def buildConcensus(kmers, looklength):
    """
    Takes a list (for each keyed anchor), and a sequence of bases up to looklength;
    Computes base composition of the next seq of bases and outputs
    total num per base, and consensus fraction and base
    """
    baseCount = []  # number at that position
    baseComp = ''   # which is the most frequent base
    baseFrac = []   # what is its frequency

    logging.info("Called.")

    for j in range(1, (looklength-1)): #loop through each base ahead
        mycounter = []                              # initialize dummy var
        for eachseq in kmers:                       # loop through each sequence;
            if len(eachseq) > (j-1):                # test if the sequence is bigger than jth
                mycounter.append(eachseq[j:j+1])    # record the ith base

        vA = mycounter.count("A")
        vT = mycounter.count("T")
        vC = mycounter.count("C")
        vG = mycounter.count("G")

        n = vA + vT + vC + vG

        # add n to counter position j
        if n > 0 :
            baseCount.append(n)
            if (vA == max(vA, vT, vC, vG)): # assign vT add a T to the string
                baseComp += 'A'
                baseFrac.append(vA/n)
            if (vC == max(vA,vT,vC,vG)):    # assign vT add a T to the string
                baseComp += 'C'
                baseFrac.append(vC/n)
            if (vG == max(vA,vT,vC, vG)):   # assign vT add a T to the string
                baseComp += 'G'
                baseFrac.append(vG/n)
            if (vT == max(vA,vT,vC, vG)):   # assign vT add a T to the string
                baseComp += 'T'
                baseFrac.append(vT/n)

    return baseComp, baseFrac, baseCount


def recordNextKmers(anchorlist, looklength, adj_dist, adj_len, myseqs, anchorlength, DNAdict, signif_anchors, anchor_dict):
    """
    anchorlist is a list -- we will loopthrough the sequence myseq and check if any of the anchorlist kmers are defined
    anchorlength is length of kmers in file
    LOOK AHEAD IN THE STRING
    """
    for myseq in myseqs:
    # loop through each kmer in the read;
    # if it is part of the old dictionary, which gets passed in, record all of the mkers
        for i in range(1, len(myseq)):
            # get substr at the ith position of length anchorlength to compare to anchorlist
            mystring = myseq[i:i+anchorlength]
             # check if it exists
            if mystring in anchorlist:
                # find where the match is
                match = myseq.find(mystring)

                s = match
                e = match + len(mystring)

                # test if the stringlength is long enough to get the string
                nextkmer = myseq [e:e+looklength]
                # keep dict small so less than 100 seqs:
                if len(DNAdict[mystring]) < 100:
                    DNAdict[mystring].append(nextkmer)

        # search for signif_anchor and log its adjacent kmer
        if any(anchor in myseq for anchor in signif_anchors):
            matching_anchors = [a for a in signif_anchors if a in myseq]

            for anchor in matching_anchors:
                # get anchor position
                anchor_end = myseq.index(anchor) + len(anchor)
                # get adjacent anchor position
                adj_anchor_start = anchor_end + adj_dist
                adj_anchor_end = adj_anchor_start + adj_len
                adj_anchor = myseq[adj_anchor_start:adj_anchor_end]

                # if adj anchor exists, add adj anchor to anchor_dict
                if len(adj_anchor) == adj_len:
                    adj_anchor_list = anchor_dict[anchor]
                    if adj_anchor not in adj_anchor_list:
                        adj_anchor_list.append(adj_anchor)
                    anchor_dict[anchor] = adj_anchor_list

    return DNAdict, anchor_dict


def returnSeqs(fastq_file, maxlines):
    """
    GETTING REAL SEQS
    """
    logging.info("Counting total number of reads in returnSeqs...")

    myseqs = []
    with gzip.open(fastq_file, 'rt') as fastq_reader:
        # stream fastq file and output if necessary
        for record in SeqIO.parse(fastq_reader, 'fastq'):
            read = str(record.seq)
            if len(myseqs) < maxlines:
                myseqs.append(read)
            else:
                break

    return myseqs


def returnAnchors(infile):
    """
    GETTING REAL SEQS
    """
    logging.info("Counting total number of reads in returnAnchors...")

    anchors=[]
    # Count reads
    tot_lines =  0

    with gzip.open(infile, "rt") as handle:

        # parse read
        for line in handle:

            # check we're in sequence line (remainder of 2)
            tot_lines += 1
            if tot_lines>1 :
                # strip of new line character
                qval = line.strip().split("\t")[5]
                seq = line.strip().split("\t")[6]


               ### edit so that either qup or qdown is less than 0.01
                if float(qval) < .01 : # lots of clusters
                    anchors.append(seq)
    return list(set(anchors))


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--signif_anchors_file",
        type=str,
        help='input list of all significant anchors'
    )
    parser.add_argument(
        "--anchors_annot",
        type=str,
        help='input anchor file from dgmfinder'
    )
    parser.add_argument("--fastq_file",
        type=str,
        help='input fasta file'
    )
    parser.add_argument("--fastq_id",
        type=str,
        help='fastq id name'
    )
    parser.add_argument("--out_fasta_file",
        type=str,
        help='output fasta file'
    )
    parser.add_argument("--out_counts_file",
        type=str,
        help='output counts file'
    )
    parser.add_argument("--out_fractions_file",
        type=str,
        help='output fractions file'
    )
    parser.add_argument("--out_adj_kmer_file",
        type=str,
        help='output adj_kmer file'
    )
    parser.add_argument("--looklength",
        type=int,
        help='lookahead length'
    )
    parser.add_argument(
        "--kmer_size",
        type=int,
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


def write_out(nextseqs, looklength, out_fasta_file, out_counts_file, out_fractions_file):
    """
    write out files
    """
    # filse for writing
    outfile_1 = open(out_fasta_file, "w")
    outfile_2 = open(out_counts_file, "w")
    outfile_3 = open(out_fractions_file, "w")

    for kk in nextseqs.keys():
    # gets the value as an array
    # syntax for getting the values of a key
        if len(nextseqs.get(kk)) > 0 :  # build concensus
            out = buildConcensus(nextseqs.get(kk), looklength)
            if len(out[1])>0:
                logging.info(kk+"--->"+out[0])
                logging.info("PRINTING")

                outfile_1.write(
                    f'>{kk}\n{out[0]}\n'
                )

                str2 = '\t'.join([str(x) for x in out[1]])+'\n'
                outfile_2.write(
                    f'{kk}\t{out[0]}\t{str2}'
                )

                str3 = '\t'.join([str(x) for x in out[2]])+'\n'
                outfile_3.write(
                    f'{kk}\t{out[0]}\t{str3}\n'
                )

    outfile_1.close()
    outfile_2.close()
    outfile_3.close()


def main():
    args = get_args()

    logging.basicConfig(
        filename = f'{args.fastq_id}.log',
        format='%(asctime)s %(levelname)-8s %(message)s',
        level=logging.INFO,
        filemode='w',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    logging.info(f'============INPUTS============')
    logging.info(f'anchors_annot    : {args.anchors_annot}')
    logging.info(f'fastq_file       : {args.fastq_file}')
    logging.info(f'looklength       : {args.looklength}')
    logging.info(f'==============================')
    logging.info('')

    # if adj_dist is not provided, use lookahead distance
    if args.adj_dist is None:
        with gzip.open(args.fastq_file, 'rt') as reader:
            head = [next(reader) for x in range(2)]

        read_len = len(head[1].strip())
        adj_dist = int((read_len - 2 * args.kmer_size) / 2)

    else:
        adj_dist = args.adj_dist

    # if adj_len is not provided, use kmer_size
    if args.adj_len is None:
        adj_len = args.kmer_size
    else:
        adj_len = args.adj_len


    # get reads from fastq
    myseqs = returnSeqs(
        args.fastq_file,
        maxlines=1000000
    )

    # get per-sample anchors
    anchorlist = returnAnchors(
        args.anchors_annot
    )

    # DNA dictionary stores the set of reads after each anchor in the angorlist
    DNAdict = {}
    for an in anchorlist:
        DNAdict[an] = []

    # dict for significant anchors and their downstream kmers
    anchor_dict = {}
    # get anchors for all samples and append to dict
    with open(args.signif_anchors_file) as file:
        signif_anchors = file.readlines()
        signif_anchors = [line.rstrip() for line in signif_anchors]
    for anchor in signif_anchors:
        anchor_dict[anchor] = []

    # get anchorlength
    anchorlength = 1
    if len(anchorlist) > 0 :
        anchorlength = len(anchorlist[0])

    # get all of the next kmers for the anchors in PREPARATION FOR BUILDING CONCENSUS
    nextseqs, anchor_dict = recordNextKmers(
        anchorlist,
        args.looklength,
        adj_dist,
        adj_len,
        myseqs,
        anchorlength,
        DNAdict,
        signif_anchors,
        anchor_dict
    )

    # write out anchor dict for merging later
    anchor_df = (
        pd.DataFrame.from_dict(
            anchor_dict,
            orient='index'
        )
        .reset_index()
        .melt(id_vars='index')
        .dropna()
        [['index', 'value']]
    )

    anchor_df.to_csv(
        args.out_adj_kmer_file,
        index=False,
        sep='\t'
    )

    write_out(
        nextseqs,
        args.looklength,
        args.out_fasta_file,
        args.out_counts_file,
        args.out_fractions_file
    )

    logging.info(f'Completed!')


if __name__ == '__main__':
    main()
