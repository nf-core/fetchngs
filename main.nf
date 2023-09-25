#!/usr/bin/env nextflow

/*
========================================================================================
    nf-core/fetchngs
========================================================================================
    Github : https://github.com/nf-core/fetchngs
    Website: https://nf-co.re/fetchngs
    Slack  : https://nfcore.slack.com/channels/fetchngs
========================================================================================
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

include { paramsHelp; paramsSummaryLog; validateParameters } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

// Print help message if needed
if (params.help) {
    def String command = "nextflow run ${workflow.manifest.name} --input id.csv -profile docker"
    log.info logo + paramsHelp(command) + citation + NfcoreTemplate.dashedLine(params.monochrome_logs)
    System.exit(0)
}

// Validate input parameters
if (params.validate_params) {
    validateParameters()
}

// Check if --input file is empty
ch_input = file(params.input, checkIfExists: true)
if (ch_input.isEmpty()) { error("File provided with --input is empty: ${ch_input.getName()}!") }

// Read in ids from --input file
ch_ids = Channel.from(file(params.input, checkIfExists: true))
    .splitCsv(header:false, sep:'', strip:true)
    .map { it[0] }
    .unique()

// Auto-detect input type
def input_type = ''
if (WorkflowMain.isSraId(ch_input))          { input_type = 'sra' }
else if (WorkflowMain.isSynapseId(ch_input)) { input_type = 'synapse' }
else                                         { error('Ids provided via --input not recognised please make sure they are either SRA / ENA / GEO / DDBJ or Synapse ids!') }
if (params.input_type != input_type)         { error("Ids auto-detected as ${input_type}. Please provide '--input_type ${input_type}' as a parameter to the pipeline!") }

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

if (params.input_type == 'sra') {
    def valid_params = [
        ena_metadata_fields : ['run_accession', 'experiment_accession', 'library_layout', 'fastq_ftp', 'fastq_md5']
    ]

    // Validate input parameters
    WorkflowSra.initialise(params, valid_params)
}

if (params.input_type == 'synapse') {

    // Create channel for synapse config
    if (params.synapse_config) {
        ch_synapse_config = file(params.synapse_config, checkIfExists: true)
    } else {
        error('Please provide a Synapse config file for download authentication!')
    }

}

/*
========================================================================================
    IMPORT MODULES
========================================================================================
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions'
include { INITIALISE                  } from './subworkflows/nf-core/initialise/main'

/*
========================================================================================
    IMPORT WORKFLOWS
========================================================================================
*/

if (params.input_type == 'sra')     include { SRA     } from './workflows/sra'
if (params.input_type == 'synapse') include { SYNAPSE } from './workflows/synapse'

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

//
// WORKFLOW: Run main nf-core/fetchngs analysis pipeline depending on type of identifier provided
//
workflow NFCORE_FETCHNGS {
    INITIALISE(params.version, params.help, params.valid_params)

    ch_versions = Channel.empty()

    // WORKFLOW: Download FastQ files for SRA / ENA / GEO / DDBJ ids
    if (params.input_type == 'sra') {
        SRA(ch_ids, params.sample_mapping_fields)
        ch_versions = ch_versions.mix(SRA.out.versions)

    // WORKFLOW: Download FastQ files for Synapse ids
    } else if (params.input_type == 'synapse') {
        SYNAPSE(ch_ids, ch_synapse_config)
        ch_versions = ch_versions.mix(SYNAPSE.out.versions)
    }

    // MODULE: Dump software versions for all tools used in the workflow
    CUSTOM_DUMPSOFTWAREVERSIONS(ch_versions.unique().collectFile(name: 'collated_versions.yml'))
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
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.input_type == 'sra')     { WorkflowSra.curateSamplesheetWarn(log) }
    if (params.input_type == 'synapse') { WorkflowSynapse.curateSamplesheetWarn(log) }
}

/*
========================================================================================
    THE END
========================================================================================
*/
