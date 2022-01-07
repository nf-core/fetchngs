#!/usr/bin/env python

import gzip
import os
import re
import sys
import argparse
import logging


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


def recordNextKmers(anchorlist, looklength, myseqs, anchorlength, DNAdict):
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
                go = min(len(myseq), (e+looklength))
                nextkmer = myseq [e:e+looklength]
                # keep dict small so less than 100 seqs:
                if len(DNAdict[mystring]) < 100:
                    DNAdict[mystring].append(nextkmer)
    return DNAdict


def returnSeqs(fastq_file, maxlines):
    """
    GETTING REAL SEQS
    """
    logging.info("Counting total number of reads in returnSeqs...")

    myseqs=[]
    # Count reads
    tot_lines =  0
    with gzip.open(fastq_file, "rt") as handle:

        # parse reads
        for read_seq in handle:
            # check we're in sequence line (remainder of 2)
            tot_lines += 1
            if tot_lines%4 != 2:
                continue
            # strip of new line character
            read_seq = read_seq.strip('\n')
            if len(myseqs)< maxlines:
                myseqs.append(read_seq)
    return(myseqs)


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


def writeSeqInfoFiles(fastq_id, anchors_annot, fastq_file, looklength):
    myseqs = returnSeqs(
        fastq_file,
        maxlines=1000000
    )

    anchorlist=returnAnchors(anchors_annot)

    ## DNA dictionary stores the set of reads after each anchor in the angorlist
    DNAdict = {}

    #initialize
    anchorlength = 1
    if len(anchorlist) > 0 :
        anchorlength = len(anchorlist[0])

    for an in anchorlist:
        DNAdict[an] = []

    # get all of the next kmers for the anchors in PREPARATION FOR BUILDING CONCENSUS
    nextseqs = recordNextKmers(
        anchorlist,
        looklength,
        myseqs,
        anchorlength,
        DNAdict     # should be a list
    )
    external_file1 = open(f'{fastq_id}_consensus.fasta', "w")
    external_file2 = open(f'{fastq_id}_fractions.tab', "w")
    external_file3 = open(f'{fastq_id}_counts.tab' , "w")

    for kk in nextseqs.keys():
    # gets the value as an array?
    # syntax for getting the values of a key
        if len(nextseqs.get(kk)) > 0 :  # build concensus
            out = buildConcensus(nextseqs.get(kk), looklength)
            if len(out[1])>0:
                logging.info(kk+"--->"+out[0])
                logging.info("PRINTING")

                external_file1.write(
                    f'>{kk}\n{out[0]}\n'
                )

                str2 = '\t'.join([str(x) for x in out[1]])+'\n'
                external_file2.write(
                    f'{kk}\t{out[0]}\t{str2}'
                )

                str3 = '\t'.join([str(x) for x in out[2]])+'\n'
                external_file3.write(
                    f'{kk}\t{out[0]}\t{str3}\n'
                )

    external_file1.close()
    external_file2.close()
    external_file3.close()


def get_args():
    parser = argparse.ArgumentParser()
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
    parser.add_argument("--looklength",
        type=int,
        help='lookahead length'
    )
    args = parser.parse_args()
    return args


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
    logging.info(f'anchors_annot     : {args.anchors_annot}')
    logging.info(f'fastq_file       : {args.fastq_file}')
    logging.info(f'looklength       : {args.looklength}')
    logging.info(f'==============================')
    logging.info('')

    writeSeqInfoFiles(
        args.fastq_id,
        args.anchors_annot,
        args.fastq_file,
        args.looklength
    )

    logging.info(f'Completed!')


if __name__ == '__main__':
    main()
