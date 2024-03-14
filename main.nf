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

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SRA } from './workflows/sra'

//
// WORKFLOW: Run main nf-core/fetchngs analysis pipeline depending on type of identifier provided
//
workflow NFCORE_FETCHNGS {

    take:
    ids // channel: database ids read in from --input

    main:

    //
    // WORKFLOW: Download FastQ files for SRA / ENA / GEO / DDBJ ids
    //
    SRA ( ids )

    emit:
    runinfo_tsv     = SRA.out.runinfo_tsv
    fastq           = SRA.out.fastq
    fastq_md5       = SRA.out.fastq_md5
    samplesheet     = SRA.out.samplesheet
    mappings        = SRA.out.mappings
    sample_mappings = SRA.out.sample_mappings
    sra_metadata    = SRA.out.sra_metadata

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_fetchngs_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_fetchngs_pipeline'

//
// WORKFLOW: Execute a single named workflow for the pipeline
//
workflow {

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.help,
        params.validate_params,
        params.monochrome_logs,
        params.outdir,
        params.input,
        params.ena_metadata_fields
    )

    //
    // WORKFLOW: Run primary workflows for the pipeline
    //
    NFCORE_FETCHNGS (
        PIPELINE_INITIALISATION.out.ids
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url
    )

    output:
    path(params.outdir, mode: params.publish_dir_mode) {
        path('fastq') {
            select NFCORE_FETCHNGS.out.fastq
        }

        path('fastq/md5') {
            select NFCORE_FETCHNGS.out.fastq_md5
        }

        path('metadata') {
            select NFCORE_FETCHNGS.out.runinfo_tsv
        }

        path('samplesheet') {
            select NFCORE_FETCHNGS.out.samplesheet, schema: 'assets/schema_samplesheet.yml'
            select NFCORE_FETCHNGS.out.mappings, schema: 'assets/schema_mappings.yml'
            select NFCORE_FETCHNGS.out.sample_mappings
        }
    }

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
