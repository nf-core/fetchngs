#!/usr/bin/env python


import argparse
import cgi
import csv
import gzip
import logging
import os
import re
import sys
import zlib
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import urlopen


logger = logging.getLogger()


# Example ids supported by this script
SRA_IDS = (
    "PRJNA63463",
    "SAMN00765663",
    "SRA023522",
    "SRP003255",
    "SRR390278",
    "SRS282569",
    "SRX111814",
)
ENA_IDS = (
    "PRJEB7743",
    "SAMEA3121481",
    "ERA2421642",
    "ERP120836",
    "ERR674736",
    "ERS4399631",
    "ERX629702",
)
DDBJ_IDS = (
    "PRJDB4176",
    "SAMD00114846",
    "DRA008156",
    "DRP004793",
    "DRR171822",
    "DRS090921",
    "DRX162434",
)
GEO_IDS = ("GSE18729", "GSM465244")
ID_REGEX = re.compile(r"^([A-Z]+)([0-9]+)$")
PREFIX_LIST = sorted(
    {ID_REGEX.match(id).group(1) for id in SRA_IDS + ENA_IDS + DDBJ_IDS + GEO_IDS}
)


# List of metadata fields fetched from the ENA API - can be overriden by options
# `-ef` or `--ena_metadata_fields`.
# Full list of accepted fields can be obtained here:
# https://www.ebi.ac.uk/ena/portal/api/returnFields?dataPortal=ena&format=tsv&result=read_run
ENA_METADATA_FIELDS = (
    "accession",
    "run_accession",
    "experiment_accession",
    "sample_accession",
    "secondary_sample_accession",
    "study_accession",
    "secondary_study_accession",
    "parent_study",
    "submission_accession",
    "run_alias",
    "experiment_alias",
    "sample_alias",
    "study_alias",
    "library_layout",
    "library_selection",
    "library_source",
    "library_strategy",
    "library_name",
    "instrument_model",
    "instrument_platform",
    "base_count",
    "read_count",
    "tax_id",
    "scientific_name",
    "sample_title",
    "experiment_title",
    "study_title",
    "description",
    "sample_description",
    "fastq_md5",
    "fastq_bytes",
    "fastq_ftp",
    "fastq_galaxy",
    "fastq_aspera",
)


class Response:
    """
    Define an HTTP response class.

    This class should not have to be instantiated directly.

    Attributes:
        status (int): The numeric HTTP status code of the response.
        reason (str): The response's reason phrase.
        body (bytes): The response's decompressed body content as bytes.

    Methods:
        text: The response's body as a decoded string.

    """

    def __init__(self, *, response, **kwargs):
        """
        Initialize an HTTP response object.

        Args:
            response (http.client.HTTPResponse): A standard library response object
                that is wrapped by this class.
            **kwargs: Passed to parent classes.

        """
        super().__init__(**kwargs)
        self._response = response
        # Immediately read the body while the response context is still available.
        self._raw = self._response.read()
        self._content = None

    def _decompress(self):
        """Decompress the response body if necessary."""
        method = self._response.getheader("Content-Encoding", "")
        if not method:
            self._content = self._raw
            return
        if method == "gzip":
            self._content = gzip.decompress(self._raw)
        elif method == "deflate":
            self._content = zlib.decompress(self._raw)
        else:
            raise ValueError(f"Unsupported compression: {method}")

    @property
    def status(self):
        """Get the response's HTTP status code."""
        return self._response.status

    @property
    def reason(self):
        """Get the response's reason phrase."""
        return self._response.reason

    @property
    def body(self):
        """Get the response's decompressed body content as bytes."""
        if self._content is None:
            self._decompress()
        return self._content

    def text(self, encoding=None):
        """Return the response's body as a decoded string."""
        if encoding is None:
            _, params = cgi.parse_header(self._response.getheader("Content-Type", ""))
            encoding = params.get("charset", "utf-8")
        return self.body.decode(encoding)


class DatabaseIdentifierChecker:
    """Define a service class for validating database identifiers."""

    _VALID_PREFIXES = frozenset(PREFIX_LIST)

    @classmethod
    def is_valid(cls, identifier):
        """
        Check the validity of the given database identifier.

        Args:
            identifier (str): A short identifier presumably belonging to one of the
                supported databases.

        Returns:
            bool: Whether or not the identifier is valid.

        """
        match = ID_REGEX.match(identifier)
        if match is None:
            return False
        return match.group(1) in cls._VALID_PREFIXES


class DatabaseResolver:
    """Define a service class for resolving various identifiers to experiments."""

    _GEO_PREFIXES = {
        "GSE",
        "GSM"
    }
    _SRA_PREFIXES = {
        "PRJNA",
        "SAMN",
        "SRR",
        "DRA",
        "DRP",
        "DRR",
        "DRS",
        "DRX",
        "PRJDB",
        "SAMD",
    }
    _ENA_PREFIXES = {
        "ERR"
    }

    @classmethod
    def expand_identifier(cls, identifier):
        """
        Expand the given identifier to potentially multiple experiment identifiers.

        Args:
            identifier (str): A short identifier presumably belonging to one of the
                supported databases.

        Returns:
            list: A list of one or more SRA/ENA experiment identifiers.

        """
        prefix = ID_REGEX.match(identifier).group(1)
        if prefix in cls._GEO_PREFIXES:
            return cls._gse_to_srx(identifier)
        elif prefix in cls._SRA_PREFIXES:
            return cls._id_to_srx(identifier)
        elif prefix in cls._ENA_PREFIXES:
            return cls._id_to_erx(identifier)
        else:
            return [identifier]

    @classmethod
    def _content_check(cls, response, identifier):
        """Check that the response has content or terminate."""
        if response.status == 204:
            logger.error(
                f"There is no content for id {identifier}. Maybe you lack the right "
                f"permissions?"
            )
            sys.exit(1)

    @classmethod
    def _id_to_srx(cls, identifier):
        """Resolve the identifier to SRA experiments."""
        params = {
            "id": identifier,
            "db": "sra",
            "rettype": "runinfo",
            "retmode": "text"
        }
        response = fetch_url(
            f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?{urlencode(params)}"
        )
        cls._content_check(response, identifier)
        return [row["Experiment"] for row in open_table(response, delimiter=",")]

    @classmethod
    def _gse_to_srx(cls, identifier):
        """Resolve the identifier to SRA experiments."""
        ids = []
        params = {
            "id": identifier,
            "db": "gds",
            "rettype": "runinfo",
            "retmode": "text"
        }
        response = fetch_url(
            f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?{urlencode(params)}"
        )
        cls._content_check(response, identifier)
        gsm_ids = [
            line.split("=")[1].strip()
            for line in response.text().splitlines()
            if line.split('=')[1].strip().startswith('GSM')
        ]
        for gsm_id in gsm_ids:
            ids += cls._id_to_srx(gsm_id)
        return ids

    @classmethod
    def _id_to_erx(cls, identifier):
        """Resolve the identifier to ENA experiments."""
        fields = ["run_accession", "experiment_accession"]
        params = {
            "accession": identifier,
            "result": "read_run",
            "fields": ",".join(fields),
        }
        response = fetch_url(
            f"https://www.ebi.ac.uk/ena/portal/api/filereport?{urlencode(params)}"
        )
        cls._content_check(response, identifier)
        return [
            row["experiment_accession"] for row in open_table(response, delimiter="\t")
        ]


class ENAMetadataFetcher:
    """Define a service class for fetching metadata from ENA."""

    def __init__(self, ena_metadata_fields, **kwargs):
        """
        Initialize the service with the desired metadata fields.

        Args:
            ena_metadata_fields (iterable): An iterable of the desired fields.
            **kwargs: Passed to parent constructor.
        """
        super().__init__(**kwargs)
        self._params = {"result": "read_run", "fields": ",".join(ena_metadata_fields)}

    def open_experiment_table(self, accession):
        """
        Open the metadata table belonging to the given experiment accession.

        Args:
            accession (str): An ENA experiment accession.

        Returns:
            csv.DictReader: A CSV reader instance of the metadata.

        """
        params = {**self._params, "accession": accession}
        response = fetch_url(
            f"https://www.ebi.ac.uk/ena/portal/api/filereport?{urlencode(params)}"
        )
        self._content_check(response, accession)
        return open_table(response, delimiter="\t")

    @classmethod
    def _content_check(cls, response, identifier):
        """Check that the response has content or terminate."""
        if response.status == 204:
            logger.error(
                f"There is no content for id {identifier}. Maybe you lack the right "
                f"permissions?"
            )
            sys.exit(1)


def open_table(response, delimiter=","):
    """
    Return a CSV reader instance from the given response.

    Args:
        response (Response): An instance of the local HTTP response class.
        delimiter (str): The delimiter separating the table fields.

    Returns:
            csv.DictReader: A CSV reader instance of the response body.

    """
    return csv.DictReader(response.text().splitlines(), delimiter=delimiter)


def parse_args(args=None):
    parser = argparse.ArgumentParser(
        description="Download and create a run information metadata file from SRA / "
        "ENA / DDBJ / GEO identifiers.",
        epilog="Example usage: python fetch_sra_runinfo.py <FILE_IN> <FILE_OUT>",
    )
    parser.add_argument(
        "file_in",
        metavar="FILE_IN",
        type=Path,
        help="File containing database identifiers, one per line.",
    )
    parser.add_argument(
        "file_out",
        metavar="FILE_OUT",
        type=Path,
        help="Output file in tab-delimited format.",
    )
    parser.add_argument(
        "-ef",
        "--ena_metadata_fields",
        type=str,
        default=",".join(ENA_METADATA_FIELDS),
        help=f"Comma-separated list of ENA metadata fields to fetch "
        f"(default: {','.join(ENA_METADATA_FIELDS)}).",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(args)


def validate_fields_parameter(param, valid_vals, param_desc):
    if not param:
        return []
    user_vals = param.split(",")
    if len(set(user_vals) & set(valid_vals)) == len(user_vals):
        return user_vals
    else:
        logger.error(
            f"Please provide a valid value for {param_desc}!\n"
            f"Provided values = {param}\n"
            f"Accepted values = {','.join(valid_vals)}"
        )
        sys.exit(1)


def fetch_url(url):
    """Return a response object for the given URL and handle errors appropriately."""
    try:
        with urlopen(url) as response:
            return Response(response=response)
    except HTTPError as e:
        logger.error("The server couldn't fulfill the request.")
        logger.error(f"Status: {e.code} {e.reason}")
        sys.exit(1)
    except URLError as e:
        logger.error("We failed to reach a server.")
        logger.error(f"Reason: {e.reason}")
        sys.exit(1)


def get_ena_fields():
    params = {"dataPortal": "ena", "format": "tsv", "result": "read_run"}
    return [
        row["columnId"]
        for row in open_table(
            fetch_url(
                f"https://www.ebi.ac.uk/ena/portal/api/returnFields?{urlencode(params)}"
            ),
            delimiter="\t",
        )
    ]


def fetch_sra_runinfo(file_in, file_out, ena_metadata_fields):
    seen_ids = set()
    run_ids = set()
    ena_fetcher = ENAMetadataFetcher(ena_metadata_fields)
    with open(file_in, "r") as fin, open(file_out, "w") as fout:
        writer = csv.DictWriter(fout, fieldnames=ena_metadata_fields, delimiter="\t")
        writer.writeheader()
        for line in fin:
            db_id = line.strip()
            if db_id in seen_ids:
                continue
            seen_ids.add(db_id)
            if not DatabaseIdentifierChecker.is_valid(db_id):
                id_str = ", ".join([x + "*" for x in PREFIX_LIST])
                logger.error(
                    f"Please provide a valid database id starting with {id_str}!\n"
                    f"Line: '{line.strip()}'"
                )
                sys.exit(1)
            ids = DatabaseResolver.expand_identifier(db_id)
            if not ids:
                logger.error(
                    f"No matches found for database id {db_id}!\nLine: '{line.strip()}'"
                )
                sys.exit(1)
            for accession in ids:
                for row in ena_fetcher.open_experiment_table(accession):
                    run_accession = row["run_accession"]
                    if run_accession not in run_ids:
                        writer.writerow(row)
                        run_ids.add(run_accession)


def main(args=None):
    args = parse_args(args)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")
    if not args.file_in.is_file():
        logger.error(f"The given input file {args.file_in} was not found!")
        sys.exit(1)
    args.file_out.parent.mkdir(parents=True, exist_ok=True)
    ena_metadata_fields = validate_fields_parameter(
        args.ena_metadata_fields,
        valid_vals=get_ena_fields(),
        param_desc="--ena_metadata_fields",
    )
    fetch_sra_runinfo(args.file_in, args.file_out, ena_metadata_fields)


if __name__ == "__main__":
    sys.exit(main())
