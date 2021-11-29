# nf-core/fetchngs: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [[1.5](https://github.com/nf-core/fetchngs/releases/tag/1.5)] - 2021-11-29

* Finish porting the pipeline to the updated Nextflow DSL2 syntax adopted on nf-core/modules
    * Bump minimum Nextflow version from `21.04.0` -> `21.10.3`
    * Removed `--publish_dir_mode` as it is no longer required for the new syntax

### Enhancements & fixes

## [[1.4](https://github.com/nf-core/fetchngs/releases/tag/1.4)] - 2021-11-09

### Enhancements & fixes

* Convert pipeline to updated Nextflow DSL2 syntax for future adoption across nf-core
* Added a workflow to download FastQ files and to create samplesheets for ids from the [Synapse platform](https://www.synapse.org/) hosted by [Sage Bionetworks](https://sagebionetworks.org/).
* SRA identifiers not available for direct download via the ENA FTP will now be downloaded via [`sra-tools`](https://github.com/ncbi/sra-tools).
* Added `--force_sratools_download` parameter to preferentially download all FastQ files via `sra-tools` instead of ENA FTP.
* Correctly handle errors from SRA identifiers that do **not** return metadata, for example, due to being private.
* Retry an error in prefetch via bash script in order to allow it to resume interrupted downloads.
* Name output FastQ files by `{EXP_ACC}_{RUN_ACC}*fastq.gz` instead of `{EXP_ACC}_{T*}*fastq.gz` for run id provenance
* [[#46](https://github.com/nf-core/fetchngs/issues/46)] - Bug in sra_ids_to_runinfo.py
* Added support for [DDBJ ids](https://www.ddbj.nig.ac.jp/index-e.html). See examples below:

| `DDBJ`        |
|---------------|
| PRJDB4176     |
| SAMD00114846  |
| DRA008156     |
| DRP004793     |
| DRR171822     |
| DRS090921     |
| DRX162434     |

## [[1.3](https://github.com/nf-core/fetchngs/releases/tag/1.3)] - 2021-09-15

### Enhancements & fixes

* Replaced Python `requests` with `urllib` to fetch ENA metadata

### Software dependencies

| Dependency  | Old version | New version |
|-------------|-------------|-------------|
| `python`    | 3.8.3       | 3.9.5       |

## [[1.2](https://github.com/nf-core/fetchngs/releases/tag/1.2)] - 2021-07-28

### Enhancements & fixes

* Updated pipeline template to [nf-core/tools 2.1](https://github.com/nf-core/tools/releases/tag/2.1)
* [[#26](https://github.com/nf-core/fetchngs/pull/26)] - Update broken EBI API URL

## [[1.1](https://github.com/nf-core/fetchngs/releases/tag/1.1)] - 2021-06-22

### Enhancements & fixes

* [[#12](https://github.com/nf-core/fetchngs/issues/12)] - Error when using singularity - /etc/resolv.conf doesn't exist in container
* Added `--sample_mapping_fields` parameter to create a separate `id_mappings.csv` and `multiqc_config.yml` with selected fields that can be used to rename samples in general and in [MultiQC](https://multiqc.info/docs/#bulk-sample-renaming)

## [[1.0](https://github.com/nf-core/fetchngs/releases/tag/1.0)] - 2021-06-08

Initial release of nf-core/fetchngs, created with the [nf-core](https://nf-co.re/) template.

## Pipeline summary

Via a single file of ids, provided one-per-line the pipeline performs the following steps:

1. Resolve database ids back to appropriate experiment-level ids and to be compatible with the [ENA API](https://ena-docs.readthedocs.io/en/latest/retrieval/programmatic-access.html)
2. Fetch extensive id metadata including direct download links to FastQ files via ENA API
3. Download FastQ files in parallel via `curl` and perform `md5sum` check
4. Collate id metadata and paths to FastQ files in a single samplesheet

## Supported database ids

Currently, the following types of example identifiers are supported:

| `SRA`        | `ENA`        | `GEO`      |
|--------------|--------------|------------|
| SRR11605097  | ERR4007730   | GSM4432381 |
| SRX8171613   | ERX4009132   | GSE147507  |
| SRS6531847   | ERS4399630   |            |
| SAMN14689442 | SAMEA6638373 |            |
| SRP256957    | ERP120836    |            |
| SRA1068758   | ERA2420837   |            |
| PRJNA625551  | PRJEB37513   |            |
