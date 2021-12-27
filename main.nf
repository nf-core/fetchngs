#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/fetchngs
========================================================================================
    Github : https://github.com/nf-core/fetchngs
    Website: https://nf-co.re/fetchngs
    Slack  : https://nfcore.slack.com/channels/fetchngs
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
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
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

// Auto-detect input id type
def input_type = ''
if (WorkflowMain.isSraId(ch_input, log)) {
    input_type = 'sra'
} else if (WorkflowMain.isSynapseId(ch_input, log)) {
    input_type = 'synapse'
} else {
    exit 1, 'Ids provided via --input not recognised please make sure they are either SRA / ENA / DDBJ / GEO or Synapse ids!'
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

    //
    // WORKFLOW: Download FastQ files for SRA / ENA / DDBJ / GEO ids
    //
    if (params.input_type == 'sra') {
        SRA ( ch_ids )

    //
    // WORKFLOW: Download FastQ files for Synapse ids
    //
    } else if (params.input_type == 'synapse') {
        SYNAPSE ( ch_ids )
    }
}

/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
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
    THE END
========================================================================================
*/
