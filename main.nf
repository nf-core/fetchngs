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
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

WorkflowMain.initialise(workflow, params, log)

// Check if --input file is empty
ch_input = file(params.input, checkIfExists: true)
if (ch_input.isEmpty()) {exit 1, "File provided with --input is empty: ${ch_input.getName()}!"}

// Read in ids from --input file
Channel
    .from(file(params.input, checkIfExists: true))
    .splitCsv(header:false, sep:'', strip:true)
    .map { it[0] }
    .unique()
    .set { ch_ids }

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions'
include { MULTIQC_MAPPINGS_CONFIG     } from './modules/local/multiqc_mappings_config'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Auto-detect input id type
def input_type = ''
if (WorkflowMain.isSraId(ch_input)) {
    input_type = 'sra'
} else if (WorkflowMain.isSynapseId(ch_input)) {
    input_type = 'synapse'
} else {
    exit 1, 'Ids provided via --input not recognised please make sure they are either SRA / ENA / GEO / DDBJ or Synapse ids!'
}

if (params.input_type == input_type) {
    if (params.input_type == 'sra') {
        include { SRA } from './workflows/sra'
    } else if (params.input_type == 'synapse') {
        include { SYNAPSE } from './workflows/synapse'
    }
} else {
    exit 1, "Ids auto-detected as ${input_type}. Please provide '--input_type ${input_type}' as a parameter to the pipeline!"
}

//
// WORKFLOW: Run main nf-core/fetchngs analysis pipeline depending on type of identifier provided
//
workflow NFCORE_FETCHNGS {

    ch_versions = Channel.empty()

    //
    // WORKFLOW: Download FastQ files for SRA / ENA / GEO / DDBJ ids
    //
    if (params.input_type == 'sra') {
        SRA ( ch_ids )

    //
    // MODULE: Create a MutiQC config file with sample name mappings
    //
        if (params.sample_mapping_fields) {
            MULTIQC_MAPPINGS_CONFIG (SRA.out.mappings)
            ch_versions = SRA.out.versions.mix(MULTIQC_MAPPINGS_CONFIG.out.versions)
        }

    //
    // MODULE: Dump software versions for all tools used in the workflow
    //

    //
    // WORKFLOW: Download FastQ files for Synapse ids
    //
    } else if (params.input_type == 'synapse') {
        SYNAPSE ( ch_ids )
        ch_versions = SYNAPSE.out.versions
    }

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    NFCORE_FETCHNGS ()
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
    WorkflowSra.curateSamplesheetWarn(log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
