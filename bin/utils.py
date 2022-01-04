#!/usr/bin/env python

import csv
import gzip
import json
from sys import stdout
from datetime import datetime

# print message
def print_mess(mess):

    """
    Print message with timestamp.
    """

    # get timestamp and print message
    dateTimeObj = str(datetime.now())
    print("[" + dateTimeObj + "]: " + mess)

    # flush stdout
    stdout.flush()

# print fasta file in a list of sequences
def write_fasta_array_seq(x, outfile):

    """
    Writes FASTA file from list of sequences `x`.
    """

    print_mess(f"Storing FASTA file with interesting sequences in: {outfile}")

    # Init
    i = 1

    # Loop over array anr write
    hdl = open(outfile, "w")
    for seq in x:
        hdl.write(">seq_" + str(i) + "\n")
        hdl.write(str(seq)+"\n")
        i += 1

    # Close handle
    hdl.close()

# writes a 2d array
def write_2d_array_tsv(x, outfile):

    """
    Writes each row in `x` in tsv `outfile`.
    """

    print_mess("Storing output table results...")

    # Dump table into target file
    with gzip.open(outfile, 'wb') as f:
        # Init counter
        i=1
        for kmer in x:

            # Write line
            out_str = "seq_" + str(i) + "\t" + "\t".join(str(e) for e in kmer) + "\n"
            f.write(out_str.encode())

            # Increase counter
            i += 1

# writes fastq file
def write_fastq(rds, outfile):

    """
    Writes FASTQ file `outfile` with reads `rds`.
    """

    i = 1
    with gzip.open(outfile, 'wb') as f:
        for rd in rds:
            qual = "0"*len(rd)
            out_str = f"@SRR{i:08} length={len(rd)}\n{rd}\n+\n{qual}\n"
            f.write(out_str.encode())
            i += 1

# print target sequences
def write_target_seqs(data_dict, targetFile):

    print_mess("Storing target k-mers for interesting anchors...")

    # open output file to write
    with gzip.open(targetFile, "wb") as outHandle:

        # loop over keys
        for key in data_dict:

            # upstream
            for seq in data_dict[key].up_dict:

                out_str = key + '\tu\t' + str(data_dict[key].up_lkp_d) + '\t' + seq + '\t' + str(data_dict[key].up_dict[seq]) + '\n'
                outHandle.write(out_str.encode())

            # downstream
            for seq in data_dict[key].dn_dict:

                out_str = key + '\td\t' + str(data_dict[key].dn_lkp_d) + '\t' + seq + '\t' + str(data_dict[key].dn_dict[seq]) + '\n'
                outHandle.write(out_str.encode())
