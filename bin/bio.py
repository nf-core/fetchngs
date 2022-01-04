#!/usr/bin/env python

import gzip

import dgmfinder
import numpy as np
from Bio.Blast import NCBIXML
from shutil import move, copyfile
from dgmfinder.Config import Config
from os import path, makedirs, remove
from multiprocessing import cpu_count
from dgmfinder import mystats, jaccard, io
from dgmfinder.AnchorKmer import AnchorKmer
from Bio.Blast.Applications import NcbiblastnCommandline

# constants
COMPLEMENT = {'A': 'T', 'C': 'G', 'G': 'C', 'T': 'A'}
BASE_HEADER = "SEQ_ID\tASSEMBLY\tC_UP\tN_UP\tES_UP\tQVAL_UP\tMAX_ANCHOR_UP\tC_DN\tN_DN\tES_DN\tQVAL_DN\tMAX_ANCHOR_DN\tA%\tC%\tG%\tT%\tANCHORS"
BASE_HEADER_LEN = len(BASE_HEADER.split('\t'))

# reverse complement
def revcomp(seq):

    """
    Returns reverse complement of input sequence.
    """

    return "".join(COMPLEMENT.get(base, base) for base in reversed(seq))

# checks for Ns in sequence
def checknoN(seq):

    """
    Check for nucleotides (N) in k-mer. Returns true if no N is present in the sequence.
    """

    return -1==seq.find('N', 0, len(seq))

# counts number of reads in a fastq file
def count_nreads_fastq(fqfile):

    """
    Count total number of records in FASTQ file.
    """

    io.print_mess("Counting total number of reads...")

    # Count reads
    tot_lines = tot_reads = 0
    with gzip.open(fqfile, "rt") as handle:
        for _ in handle:
            tot_lines += 1
            if (tot_lines%4)==1:
                tot_reads += 1

    io.print_mess("Found " + str(tot_reads) + " reads...")

    # Return total
    return tot_reads

# processes a single fastq read or record
def process_fastq_record(no_new_kmers, read_seq, data_dict, config):

    """
    Process FASTQ record.
    """

    # Loop over sequence
    i = 0
    new_entries = 0
    while (i+config.kmer_size)<=(len(read_seq)):

        ## Take care of reference k-mer

        # Get reference k-mer
        ref_kmer = read_seq[i:(i+config.kmer_size)]

        # Check reference k-mer has no N
        if not checknoN(ref_kmer):

            # Increase counter so we move on and continue
            i += 1
            continue

        # Create entry in dictionary if it doesn't exist if worth it
        if ref_kmer not in data_dict:

            # increase new entries counter
            new_entries += 1

            # Check if accepting new k-mers at all
            if no_new_kmers:

                # Increase counter so we move on and continue
                i += 1
                continue

            # Accept k-mer if still fair game
            data_dict[ref_kmer] = AnchorKmer(ref_kmer)

            # Sample lookup distance if necessary
            data_dict[ref_kmer].up_lkp_d = np.random.choice(range(1,config.kmer_size)) if config.rand_lkp else config.dist
            data_dict[ref_kmer].dn_lkp_d = np.random.choice(range(1,config.kmer_size)) if config.rand_lkp else config.dist

        ## Check flanking k-mers at distance dist

        # Get upstream candidate variable sequence
        if not data_dict[ref_kmer].up_done and (i-(data_dict[ref_kmer].up_lkp_d+config.kmer_size-1))>=0:

            # Get upstream sequence
            up_kmer = read_seq[(i-(data_dict[ref_kmer].up_lkp_d+config.kmer_size-1)):(i-data_dict[ref_kmer].up_lkp_d+1)]

            # Register variable upstream k-mer
            if checknoN(up_kmer):

                # increase count
                data_dict[ref_kmer].up_cnt += 1

                # add new target sequence to dictionary
                xn = jaccard.add_new_val_js(data_dict[ref_kmer].up_dict, up_kmer, config.lmer_size, config.jsthrsh)

                # update xn sequence
                data_dict[ref_kmer].up_x_seq.append(xn)

            # Check if done
            data_dict[ref_kmer].up_done = True if data_dict[ref_kmer].up_cnt>=config.max_smp_sz else False

        # Get downstream candidate variable sequence
        if not data_dict[ref_kmer].dn_done and (i+2*config.kmer_size+data_dict[ref_kmer].dn_lkp_d-1)<=len(read_seq):

            # Get downstream sequence
            dn_kmer = read_seq[(i+config.kmer_size+data_dict[ref_kmer].dn_lkp_d-1):(i+2*config.kmer_size+data_dict[ref_kmer].dn_lkp_d-1)]

            # Register variable downstream k-mer
            if checknoN(dn_kmer):

                # increase count
                data_dict[ref_kmer].dn_cnt += 1

                # add new target sequence to dictionary
                xn = jaccard.add_new_val_js(data_dict[ref_kmer].dn_dict, dn_kmer, config.lmer_size, config.jsthrsh)

                # update xn sequence
                data_dict[ref_kmer].dn_x_seq.append(xn)

            # Check if done
            data_dict[ref_kmer].dn_done = True if data_dict[ref_kmer].dn_cnt>=config.max_smp_sz else False

        # Shift reference k-mer one position
        i += 1

    # return number of new entries
    return new_entries

# processes a fastq file
def process_fastq(data_dict, min_p, n_tot, fqfile, config):

    io.print_mess("Generating anchor k-mer dictionary...")

    # init aux
    n_so_far = 0
    n_achors = 0
    n_achors_p = 0
    total_lines = 0
    no_new_kmers = False

    # parse fastq file
    with gzip.open(fqfile, "rt") as handle:

        # parse read
        for read_seq in handle:

            # check we're in sequence line (remainder of 2)
            total_lines += 1
            if total_lines%4!=2:
                continue

            # increase counter
            n_so_far += 1

            # strip of new line character
            read_seq = read_seq.strip('\n')

            # process record
            n_achors += process_fastq_record(no_new_kmers, read_seq, data_dict, config)

            # report another 100k
            if n_so_far%10000==0:
                io.print_mess(f"Another 10k reads processed (total: {n_so_far}). Found {n_achors-n_achors_p} new anchors (total: {n_achors})...")
                n_achors_p = n_achors

            # check if we hit the maximum number of fastq records
            if config.max_fastq_reads>0 and n_so_far>config.max_fastq_reads:
                io.print_mess(f"Hit the maximum number of FASTQ records... Total of {n_so_far}")
                break

            # check if it is worth introducing new k-mers at all every 100,000 reads
            if not no_new_kmers and n_so_far%100000==0:

                # check if it is worth introducing new k-mers at all
                if not no_new_kmers:

                    # returns true if not worth introducing new k-mers
                    no_new_kmers = True if 1.0-(1.0-min_p)**n_so_far>0.99 else False

                    # if no new kmers anounce it and check with oracle
                    if no_new_kmers:

                        # print the first time it becomes true
                        io.print_mess("No new k-mers from now on...")

                        # check with oracle and create message
                        mystats.check_w_oracle(data_dict, n_so_far, n_tot, config)

            # from that point on, check with oracle every 5 million reads
            if no_new_kmers and n_so_far%2500000==0:

                # check with oracle and create message
                mystats.check_w_oracle(data_dict, n_so_far, n_tot, config)

# returns directory of annotations
def get_annot_paths():

    """
    Returns directory of annotations.
    """

    return path.dirname(path.dirname(path.abspath(dgmfinder.__file__)))+"/annotations/"

# annotate output file using an input fasta file
def annot_fa(stats_file, kmer_fa, annot_fa, evalue=1):

    """
    Annotates output file using annotation `annot_fa` FASTA file.
    """

    # get absolute paths
    kmer_fa = path.abspath(kmer_fa)
    annot_fa = path.abspath(annot_fa)
    stats_file = path.abspath(stats_file)

    ## blast

    io.print_mess(f"Blasting anchor k-mers in: {kmer_fa}")
    io.print_mess(f"Using subject list: {annot_fa}")

    # temporary xml file
    outdir = path.dirname(stats_file)
    anchor_bsnm = path.basename(kmer_fa).split(".")[0]
    annot_bsnm = path.basename(annot_fa).split(".")[0]
    tmpxml = outdir + "/" + anchor_bsnm + "_x_" + annot_bsnm + "_blast.xml"

    # count threads
    nthreads = cpu_count()-1
    io.print_mess(f"Running blastn with {nthreads} cpus...")

    # blast
    blastx_cline = NcbiblastnCommandline(query=kmer_fa, subject=annot_fa, evalue=evalue, outfmt=5, out=tmpxml, strand="both", task="blastn-short", num_threads=nthreads)
    blastx_cline()

    ## parse xml

    io.print_mess("Parsing blast output...")

    # get hits
    hits = []
    min_es = []
    min_titles = []

    # loop over records in xml
    for record in NCBIXML.parse(open(tmpxml)):

        # skip queries with no matches
        if record.alignments:

            # append hit
            hits.append(record.query)

            # loop over alignments
            min_e = 1.0
            min_title = None
            for alignment in record.alignments:
                for hsp in alignment.hsps:
                    if hsp.expect<min_e:
                        min_e = hsp.expect
                        min_title = ' '.join(alignment.title.split(' ')[1:])

            # append min expected
            min_es.append(min_e)
            min_titles.append(min_title)

    # make them numpy
    hits = np.array(hits)
    min_es = np.array(min_es)
    min_titles = np.array(min_titles)

    ## consolidate

    io.print_mess("Consolidating results...")

    # output file name
    out_file = stats_file.split(".", 1)[0] + "_annot.txt.gz"
    tmpfile = out_file + ".tmp"

    # create temp file
    if path.exists(out_file):
        copyfile(out_file, tmpfile)
    else:
        copyfile(stats_file, tmpfile)

    # traverse output kmer stats file and annotate
    with gzip.open(tmpfile,'r') as fin:

        with gzip.open(out_file, 'wb') as fout:

            # Go over each line in input file
            for line in fin:

                # Decode line
                line = line.decode('utf8')

                # Strip new line character
                line = line.strip()

                # Split tabs
                line_arr = line.split('\t')

                # Get reference k-mer
                seq_id = line_arr[0]

                # Construct output array
                out_str = line
                if seq_id in hits:
                    # if seq_id in hits, then print min e-value
                    idx = np.where(hits==seq_id)[0][0]
                    min_e = min_es[idx]
                    min_title = min_titles[idx]
                    out_str += f"\t{min_e}\t{min_title}\n"
                else:
                    # if not print NA
                    out_str += "\tNA\tNA\n"

                # Write to file
                fout.write(out_str.encode())

    # remove temp if it exists
    if path.exists(tmpfile):
        remove(tmpfile)

# annotate output file using an all fasta files provided
def annot_all(stats_file, kmer_fa, config, evalue=1):

    # loop over fasta files
    for fa in config.annot_fasta:

        # check fasta exists
        if path.exists(fa):

            # annotate if so
            annot_fa(stats_file, kmer_fa, fa, evalue=evalue)

# get output prefix
# def get_out_pref(fqfile, config):

#     """
#     Obtains output prefix and creates output directory if necessary.
#     """

#     if not path.exists(config.outdir):
#         io.print_mess(f"Creating output directory: {config.outdir}")
#         makedirs(config.outdir, exist_ok = True)

#     return config.outdir + "/" + path.basename(fqfile).split('.fastq')[0]

# adds header to output file
def dmgfinder_header(infile, fastas):

    # get paths
    bsnme = path.basename(infile)
    dirfile = path.dirname(infile)
    tmpfile = dirfile + bsnme.split(".")[0] + "_tmp"

    # get fastas
    fasta_array = fastas.split(",")
    fasta_array = [path.basename(fasta_array[i]) for i in range(len(fasta_array))]
    fasta_array = [fasta_array[i].split(".fa")[0] for i in range(len(fasta_array))]

    # open input file
    i = 1
    numcol = None
    with gzip.open(infile,'r') as fin:

        # open temp file
        with gzip.open(tmpfile, 'wb') as fout:

            for line in fin:

                # decode line
                unstrip_line = line.decode('utf8')

                # strip new line character
                line = unstrip_line.strip()

                # get num of cols
                if i==1:

                    # print header
                    extra_header_up = ["blast_evalue_up_" + fasta_array[i] + "\tblast_hit_up_" + fasta_array[i] for i in range(len(fasta_array))]
                    extra_header_up = "\t".join(extra_header_up)
                    extra_header_dn = ["blast_evalue_dn_" + fasta_array[i] + "\tblast_hit_dn_" + fasta_array[i] for i in range(len(fasta_array))]
                    extra_header_dn = "\t".join(extra_header_dn)
                    out_str = BASE_HEADER + "\t" + extra_header_up + "\t" + extra_header_dn + "\n"
                    fout.write(out_str.encode())

                # print line
                fout.write(unstrip_line.encode())

                # increase counter
                i += 1

    # move file
    move(tmpfile, infile)

# performs a single-sample analysis on fastq file
def dgmfinder_single_sample_analysis(fqfile, fq_id, config=Config()):

    """
    Performs a single-sample analysis on `fqfile` file.
    """

    # print name of file
    io.print_mess(f"*********************** INPUT ***********************")
    io.print_mess(f"FASTQ file: {fqfile}")

    # report configuration to logfile
    config.report()

    # init dictionary
    data_dict = {}

    # # get output prefix
    # outprefix = get_out_pref(fqfile, config)

    # count total number of reads
    n_tot = count_nreads_fastq(fqfile)

    # get minimum p of success for which we expect to see the min sample size allowed
    min_p = config.min_smp_sz/n_tot
    io.print_mess("Minimum success probability is " + str(min_p) + "...")

    # generate dictionary of k-mers
    process_fastq(data_dict, min_p, n_tot, fqfile, config)

    # run poisson testing
    test_success = mystats.poibin_test(data_dict, config)
    if not test_success:
        io.print_mess("dgmfinder finished without positives")

    # store target sequences
    io.write_target_seqs(data_dict, fq_id + "_targets.txt.gz")

    # run assembly of anchors
    kmer_stats = mystats.cllps_anchors(data_dict)

    # store output
    io.write_2d_array_tsv(kmer_stats, fq_id + "_anchors.txt.gz")
    io.write_fasta_array_seq([kmer[0] for kmer in kmer_stats], fq_id + "_assemb_anchors.fasta")

    # get maximizing individual anchor in either direction
    io.write_fasta_array_seq([kmer[5] for kmer in kmer_stats], fq_id + "_max_anchor_up.fasta")
    io.write_fasta_array_seq([kmer[10] for kmer in kmer_stats], fq_id + "_max_anchor_dn.fasta")

    # annotates output of previous step
    len(config.annot_fasta)>0 and annot_all(fq_id + "_anchors.txt.gz", fq_id + "_max_anchor_up.fasta", config)
    len(config.annot_fasta)>0 and annot_all(fq_id + "_anchors.txt.gz", fq_id + "_max_anchor_dn.fasta", config)

    # add header to output file
    len(config.annot_fasta)>0 and dmgfinder_header(fq_id + "_anchors_annot.txt.gz", ",".join(config.annot_fasta))

    io.print_mess("dgmfinder finished successfully.")

# adds annotation to processed file
def dgmfinder_single_sample_analysis_annotation(anchorFile, fq_id, config=Config()):

    """
    Adds anotation to processed file `anchorFile`.
    """

    # print name of file
    io.print_mess(f"*********************** INPUT ***********************")
    io.print_mess(f"Anchor file: {anchorFile}")
    io.print_mess(f"*****************************************************")

    # get output prefix
    # outprefix = anchorFile.split("_anchors.txt.gz")[0]

    # check if annotation file exists
    if path.exists(fq_id + "_anchors_annot.txt.gz"):
        remove(fq_id + "_anchors_annot.txt.gz")

    # annotates output of previous step
    len(config.annot_fasta)>0 and annot_all(anchorFile, fq_id + "_max_anchor_up.fasta", config)
    len(config.annot_fasta)>0 and annot_all(anchorFile, fq_id + "_max_anchor_dn.fasta", config)

    # add header to output file
    len(config.annot_fasta)>0 and dmgfinder_header(fq_id + "_anchors_annot.txt.gz", ",".join(config.annot_fasta))

    io.print_mess("dgmfinder finished successfully.")
