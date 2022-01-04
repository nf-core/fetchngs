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

//WorkflowMain.initialise(workflow, params, log)

//
// WORKFLOW: Run main nf-core/fetchngs analysis pipeline depending on type of identifier provided
//

include { SRA } from './workflows/sra'

workflow NFCORE_FETCHNGS {

    //
    // WORKFLOW: Download FastQ files for SRA / ENA / DDBJ / GEO ids
    //
    SRA ()

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
