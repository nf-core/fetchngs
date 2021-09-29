#!/usr/bin/env python

import argparse
import cgi
import csv
import errno
import gzip
import logging
import os
import re
import sys
import zlib
from urllib.error import URLError, HTTPError
from urllib.parse import urlencode
from urllib.request import urlopen

logger = logging.getLogger()

## Example ids supported by this script
SRA_IDS = ('PRJNA63463', 'SAMN00765663', 'SRA023522', 'SRP003255', 'SRR390278', 'SRS282569', 'SRX111814')
ENA_IDS = ('PRJEB7743', 'SAMEA3121481', 'ERA2421642', 'ERP120836', 'ERR674736', 'ERS4399631', 'ERX629702')
DDBJ_IDS = ('PRJDB4176', 'SAMD00114846', 'DRA008156', 'DRP004793', 'DRR171822', 'DRS090921', 'DRX162434')
GEO_IDS = ('GSE18729', 'GSM465244')
ID_REGEX = re.compile(r'[A-Z]+')
PREFIX_LIST = sorted({ID_REGEX.match(x).group() for x in SRA_IDS + ENA_IDS + DDBJ_IDS + GEO_IDS})


## List of meta fields fetched from the ENA API - can be overriden by --ena_metadata_fields
## Full list of accepted fields can be obtained here: https://www.ebi.ac.uk/ena/portal/api/returnFields?dataPortal=ena&format=tsv&result=read_run
ENA_METADATA_FIELDS = (
    'accession', 'run_accession', 'experiment_accession', 'sample_accession', 'secondary_sample_accession', 'study_accession', 'secondary_study_accession', 'parent_study', 'submission_accession',
    'run_alias', 'experiment_alias', 'sample_alias', 'study_alias',
    'library_layout', 'library_selection', 'library_source', 'library_strategy', 'library_name',
    'instrument_model', 'instrument_platform',
    'base_count', 'read_count',
    'tax_id', 'scientific_name',
    'sample_title', 'experiment_title', 'study_title',
    'description', 'sample_description',
    'fastq_md5', 'fastq_bytes', 'fastq_ftp', 'fastq_galaxy', 'fastq_aspera'
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
        if encoding is not None:
            return self.body.decode(encoding)

        _, params = cgi.parse_header(self._response.getheader("Content-Type", ""))
        encoding = params.get("charset", "utf-8")
        return self.body.decode(encoding)


def parse_args(args=None):
    Description = 'Download and create a run information metadata file from SRA / ENA / DDBJ / GEO identifiers.'
    Epilog = 'Example usage: python fetch_sra_runinfo.py <FILE_IN> <FILE_OUT>'

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument('FILE_IN', help="File containing database identifiers, one per line.")
    parser.add_argument('FILE_OUT', help="Output file in tab-delimited format.")
    parser.add_argument('-ef', '--ena_metadata_fields', type=str, dest="ENA_METADATA_FIELDS", default='', help=f"Comma-separated list of ENA metadata fields to fetch. (default: {','.join(ENA_METADATA_FIELDS)}).")
    return parser.parse_args(args)

def validate_csv_param(param, valid_vals, param_desc):
    valid_list = []
    if param:
        user_vals = param.split(',')
        intersect = [i for i in user_vals if i in valid_vals]
        if len(intersect) == len(user_vals):
            valid_list = intersect
        else:
            logger.error(f"Please provide a valid value for {param_desc}!\nProvided values = {param}\nAccepted values = {','.join(valid_vals)}")
            sys.exit(1)
    return valid_list

def make_dir(path):
    if not len(path) == 0:
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise

def fetch_url(url):
    try:
        with urlopen(url) as response:
            result = Response(response=response).text().splitlines()
    except HTTPError as e:
        logger.error("The server couldn't fulfill the request.")
        logger.error(f"Status: {e.code} {e.reason}")
        sys.exit(1)
    except URLError as e:
        logger.error('We failed to reach a server.')
        logger.error(f"Reason: {e.reason}")
        sys.exit(1)
    return result

def id_to_srx(db_id):
    params = {
        "save": "efetch",
        "db": "sra",
        "rettype": "runinfo",
        "term": db_id
    }
    url = f'https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?{urlencode(params)}'
    return [
        row['Experiment'] for row in csv.DictReader(fetch_url(url), delimiter=',')
    ]

def id_to_erx(db_id):
    fields = ['run_accession', 'experiment_accession']
    params = {
        "accession": db_id,
        "result": "read_run",
        "fields": ",".join(fields)
    }
    url = f'https://www.ebi.ac.uk/ena/portal/api/filereport?{urlencode(params)}'
    return [
        row['experiment_accession'] for row in csv.DictReader(fetch_url(url), delimiter='\t')
    ]

def gse_to_srx(db_id):
    ids = []
    params = {
        "acc": db_id,
        "targ": "gsm",
        "view": "data",
        "form": "text"
    }
    url = f'https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?{urlencode(params)}'
    gsm_ids = [x.split('=')[1].strip() for x in fetch_url(url) if x.startswith('GSM')]
    for gsm_id in gsm_ids:
        ids += id_to_srx(gsm_id)
    return ids

def get_ena_fields():
    params = {
        "dataPortal": "ena",
        "format": "tsv",
        "result": "read_run"
    }
    url = f'https://www.ebi.ac.uk/ena/portal/api/returnFields?{urlencode(params)}'
    return [
        row['columnId'] for row in csv.DictReader(fetch_url(url), delimiter='\t')
    ]

def fetch_sra_runinfo(file_in, file_out, ena_metadata_fields=ENA_METADATA_FIELDS):
    total_out = 0
    seen_ids = set()
    run_ids = set()
    header = []
    make_dir(os.path.dirname(file_out))
    params = {
        "result": "read_run",
        "fields": ','.join(ena_metadata_fields)
    }
    with open(file_in,"r") as fin, open(file_out,"w") as fout:
        for line in fin:
            db_id = line.strip()
            match = ID_REGEX.match(db_id)
            if match:
                prefix = match.group()
                if prefix in PREFIX_LIST:
                    if db_id not in seen_ids:

                        ids = [db_id]
                        ## Resolve/expand these ids against GEO URL
                        if prefix in ['GSE']:
                            ids = gse_to_srx(db_id)

                        ## Resolve/expand these ids against SRA URL
                        elif prefix in ['GSM', 'PRJNA', 'SAMN', 'SRR', 'DRA', 'DRP', 'DRR', 'DRS', 'DRX', 'PRJDB', 'SAMD']:
                            ids = id_to_srx(db_id)

                        ## Resolve/expand these ids against ENA URL
                        elif prefix in ['ERR']:
                            ids = id_to_erx(db_id)

                        ## Resolve/expand to get run identifier from ENA and write to file
                        for id in ids:
                            params["accession"] = id
                            url = f'https://www.ebi.ac.uk/ena/portal/api/filereport?{urlencode(params)}'
                            for row in csv.DictReader(fetch_url(url), delimiter='\t'):
                                run_id = row['run_accession']
                                if run_id not in run_ids:
                                    if total_out == 0:
                                        header = row.keys()
                                        header_line = '\t'.join(header)
                                        fout.write(f"{header_line}\n")
                                    else:
                                        if header != row.keys():
                                            logger.error(f"Metadata columns do not match for id {run_id}!\nLine: '{line.strip()}'")
                                            sys.exit(1)

                                    ordered_row = '\t'.join([row[x] for x in header])
                                    fout.write(f'{ordered_row}\n')
                                    total_out += 1
                                    run_ids.add(run_id)
                        seen_ids.add(db_id)

                        if not ids:
                            logger.error(f"No matches found for database id {db_id}!\nLine: '{line.strip()}'")
                            sys.exit(1)

                else:
                    id_str = ', '.join([x + "*" for x in PREFIX_LIST])
                    logger.error(f"Please provide a valid database id starting with {id_str}!\nLine: '{line.strip()}'")
                    sys.exit(1)
            else:
                id_str = ', '.join([x + "*" for x in PREFIX_LIST])
                logger.error(f"Please provide a valid database id starting with {id_str}!\nLine: '{line.strip()}'")
                sys.exit(1)

def main(args=None):
    args = parse_args(args)
    ena_metadata_fields = args.ENA_METADATA_FIELDS
    if not args.ENA_METADATA_FIELDS:
        ena_metadata_fields = ','.join(ENA_METADATA_FIELDS)
    ena_metadata_fields = validate_csv_param(ena_metadata_fields, valid_vals=get_ena_fields(), param_desc='--ena_metadata_fields')
    fetch_sra_runinfo(args.FILE_IN, args.FILE_OUT, ena_metadata_fields)

if __name__ == '__main__':
    logging.basicConfig(level='INFO', format='[%(levelname)s] %(message)s')
    sys.exit(main())
