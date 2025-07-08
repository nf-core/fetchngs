#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/fetchngs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/fetchngs
    Website: https://nf-co.re/fetchngs
    Slack  : https://nfcore.slack.com/channels/fetchngs
----------------------------------------------------------------------------------------
*/

nextflow.preview.operators = true
nextflow.preview.typeChecking = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS / TYPES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SRA                     } from './workflows/sra'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_fetchngs_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_fetchngs_pipeline'
include { SOFTWARE_VERSIONS       } from './subworkflows/nf-core/utils_nfcore_pipeline'
include { Sample                  } from './workflows/sra'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOW INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params {

    // List of SRA/ENA/GEO/DDBJ identifiers to download their associated metadata and FastQ files
    input: Path

    // Comma-separated list of ENA metadata fields to fetch before downloading data
    ena_metadata_fields: String = ''

    // Only download metadata for public data database ids and don't download the FastQ files
    skip_fastq_download: Boolean = false

    // dbGaP repository key
    dbgap_key: Path?
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    ids = PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        workflow.outputDir,
        params.input,
        params.ena_metadata_fields
    )

    //
    // WORKFLOW: Run primary workflows for the pipeline
    //
    sra = SRA (
        channel.fromList(ids),
        [
            ena_metadata_fields: params.ena_metadata_fields,
            skip_fastq_download: params.skip_fastq_download,
            dbgap_key: params.dbgap_key
        ]
    )

    //
    // SUBWORKFLOW: Collect software versions
    //
    versions = SOFTWARE_VERSIONS()

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        workflow.outputDir,
        params.monochrome_logs,
        params.hook_url
    )

    publish:
    samples = sra.samples
    runinfo_ftp = sra.runinfo_ftp
    versions = versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOW OUTPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

output {

    // List of FASTQ samples with optional MD5 checksums
    samples: Channel<Sample> {
        path { sample ->
            sample.fastq_1 >> 'fastq/'
            sample.fastq_2 >> 'fastq/'
            sample.md5_1 >> 'fastq/md5/'
            sample.md5_2 >> 'fastq/md5/'
        }
        index {
            path 'samplesheet/samplesheet.json'
        }
    }

    // List of download links for the given sample ids
    runinfo_ftp: Channel<Path> {
        path 'metadata'
    }

    // Manifest of tool versions used by the pipeline for MultiQC
    versions: Map<String,Map> {
        index {
            path 'nf_core_fetchngs_software_mqc_versions.yml'
        }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
