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
input_type = WorkflowMain.getIdentifierType(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

if (input_type == 'Synapse') {
    include { SYNAPSE } from './workflows/synapse'
} else {
    include { FETCHNGS } from './workflows/fetchngs'
}

//
// WORKFLOW: Run main nf-core/fetchngs analysis pipeline, depending on Identifier Type provided
//
workflow NFCORE_FETCHNGS {

    // Workflow for SynapseIDs
    if (input_type == 'Synapse') {
        SYNAPSE ()
    } else {
    // Workflow for SRA/ENA/GEO IDs
        FETCHNGS ()
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
