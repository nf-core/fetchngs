# nf-core/fetchngs: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
