#!/usr/bin/env python


import argparse
import csv
import logging
import sys
from itertools import chain
from pathlib import Path


logger = logging.getLogger()


def parse_args(args=None):
    Description = "Create samplesheet with FTP download links and md5ums from sample information obtained via 'sra_ids_to_runinfo.py' script."
    Epilog = "Example usage: python sra_runinfo_to_ftp.py <FILES_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument(
        "files_in",
        metavar="FILES_IN",
        help="Comma-separated list of metadata file created from 'sra_ids_to_runinfo.py' script.",
    )
    parser.add_argument(
        "file_out",
        metavar="FILE_OUT",
        type=Path,
        help="Output file containing paths to download FastQ files along with their associated md5sums.",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(args)


def valid_fastq_extension(fastq):
    return fastq.endswith("fastq.gz")


def parse_sra_runinfo(file_in):
    runinfo = {}
    columns = [
        "run_accession",
        "experiment_accession",
        "library_layout",
        "fastq_ftp",
        "fastq_md5",
    ]
    extensions = [
        "fastq_1",
        "fastq_2",
        "md5_1",
        "md5_2",
        "single_end",
    ]
    with open(file_in, "r", newline="") as fin:
        reader = csv.DictReader(fin, delimiter="\t", skipinitialspace=True)
        header = list(reader.fieldnames)
        if missing := frozenset(columns).difference(frozenset(header)):
            logger.critical(
                f"The following expected columns are missing from {file_in}: "
                f"{', '.join(missing)}."
            )
            sys.exit(1)
        for row in reader:
            db_id = row["experiment_accession"]
            if row["fastq_ftp"]:
                fq_files = row["fastq_ftp"].split(";")[-2:]
                fq_md5 = row["fastq_md5"].split(";")[-2:]
                if len(fq_files) == 1:
                    assert fq_files[0].endswith(
                        ".fastq.gz"
                    ), f"Unexpected FastQ file format {file_in.name}."
                    if row["library_layout"] != "SINGLE":
                        logger.warning(
                            f"The library layout '{row['library_layout']}' should be "
                            f"'SINGLE'."
                        )
                    sample = {
                        "fastq_1": fq_files[0],
                        "fastq_2": None,
                        "md5_1": fq_md5[0],
                        "md5_2": None,
                        "single_end": "true",
                    }
                elif len(fq_files) == 2:
                    assert fq_files[0].endswith(
                        "_1.fastq.gz"
                    ), f"Unexpected FastQ file format {file_in.name}."
                    assert fq_files[1].endswith(
                        "_2.fastq.gz"
                    ), f"Unexpected FastQ file format {file_in.name}."
                    if row["library_layout"] != "PAIRED":
                        logger.warning(
                            f"The library layout '{row['library_layout']}' should be "
                            f"'PAIRED'."
                        )
                    sample = {
                        "fastq_1": fq_files[0],
                        "fastq_2": fq_files[1],
                        "md5_1": fq_md5[0],
                        "md5_2": fq_md5[1],
                        "single_end": "false",
                    }
                else:
                    raise RuntimeError(f"Unexpected number of FastQ files: {fq_files}.")
            else:
                # In some instances, FTP links don't exist for FastQ files.
                # These have to be downloaded with the run accession using sra-tools.
                sample = dict.fromkeys(extensions, None)
                if row["library_layout"] == "SINGLE":
                    sample["single_end"] = "true"
                elif row["library_layout"] == "PAIRED":
                    sample["single_end"] = "false"

            sample.update(row)
            if db_id not in runinfo:
                runinfo[db_id] = [sample]
            else:
                if sample in runinfo[db_id]:
                    logger.error(
                        f"Input run info file contains duplicate rows!\n"
                        f"{', '.join([row[col] for col in header])}"
                    )
                else:
                    runinfo[db_id].append(sample)

    return runinfo, header + extensions


def sra_runinfo_to_ftp(files_in, file_out):
    samplesheet = {}
    header = []
    for file_in in files_in:
        runinfo, sample_header = parse_sra_runinfo(file_in)
        header.append(sample_header)
        for db_id, rows in runinfo.items():
            if db_id not in samplesheet:
                samplesheet[db_id] = rows
            else:
                logger.warning(f"Duplicate sample identifier found!\nID: '{db_id}'")

    # Create a combined header from all input files.
    combined_header = header[0] + list(
        set().union(chain.from_iterable(header)).difference(header[0])
    )
    combined_header.insert(0, "id")

    # Write samplesheet with paths to FastQ files and md5 sums.
    if samplesheet:
        with file_out.open("w", newline="") as fout:
            writer = csv.DictWriter(fout, fieldnames=combined_header, delimiter="\t")
            writer.writeheader()
            for db_id in sorted(samplesheet):
                for idx, row in enumerate(samplesheet[db_id], start=1):
                    row["id"] = f"{db_id}"
                    if 'run_accession' in row:
                        row["id"] = f"{db_id}_{row['run_accession']}"
                    writer.writerow(row)


def main(args=None):
    args = parse_args(args)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")
    files = [Path(x.strip()) for x in args.files_in.split(",")]
    for path in files:
        if not path.is_file():
            logger.critical(f"The given input file {path} was not found!")
            sys.exit(1)
    args.file_out.parent.mkdir(parents=True, exist_ok=True)
    sra_runinfo_to_ftp(files, args.file_out)


if __name__ == "__main__":
    sys.exit(main())
