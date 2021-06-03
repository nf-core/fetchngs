#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/fetchfastq
========================================================================================
    Github : https://github.com/nf-core/fetchfastq
    Website: https://nf-co.re/fetchfastq
    Slack  : https://nfcore.slack.com/channels/fetchfastq
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    GENOME PARAMETER VALUES
========================================================================================
*/

params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

workflow NFCORE_FETCHFASTQ {

    //
    // WORKFLOW: Run main nf-core/fetchfastq analysis pipeline
    //
    include { FETCHFASTQ } from './workflows/fetchfastq'
    FETCHFASTQ ()
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
    NFCORE_FETCHFASTQ ()
}

/*
========================================================================================
    THE END
========================================================================================
*/
