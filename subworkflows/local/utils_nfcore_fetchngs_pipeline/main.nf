//
// Subworkflow with functionality specific to the nf-core/fetchngs pipeline
//

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

include { completionEmail      } from 'plugin/nf-utils'
include { completionSummary    } from 'plugin/nf-utils'
include { imNotification       } from 'plugin/nf-utils'
include { paramsSummaryMap     } from 'plugin/nf-schema'
include { samplesheetToList    } from 'plugin/nf-schema'
include { getWorkflowVersion   } from 'plugin/nf-utils'
include { dumpParametersToJSON } from 'plugin/nf-utils'
include { checkCondaChannels   } from 'plugin/nf-utils'
include { checkConfigProvided  } from 'plugin/nf-utils'
include { checkProfileProvided } from 'plugin/nf-utils'
include { paramsSummaryLog     } from 'plugin/nf-schema'
include { validateParameters   } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {
    take:
    version             // boolean: Display version and exit
    validate_params     // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs     // boolean: Do not use coloured log outputs
    nextflow_cli_args   //   array: List of positional nextflow CLI args
    outdir              //  string: The output directory where the results will be saved
    input               //  string: File containing SRA/ENA/GEO/DDBJ identifiers one per line to download their associated metadata and FastQ files
    ena_metadata_fields //  string: Comma-separated list of ENA metadata fields to fetch before downloading data

    main:

    ch_versions = Channel.empty()

    // Plugin-based parameter dump and version info
    if (outdir) {
        dumpParametersToJSON(outdir, params)
    }
    def version_str = getWorkflowVersion(workflow.manifest.version, workflow.commitId)
    println("Pipeline version: ${version_str}")
    if (workflow.profile && workflow.profile.contains('conda')) {
        if (!checkCondaChannels()) {
            log.warn("Conda channels are not configured correctly!")
        }
    }

    //
    // Validate parameters and generate parameter summary to stdout
    //
    if (validate_params) {
        // Print parameter summary to stdout. This will display the parameters
        // that differ from the default given in the JSON schema
        // TODO log.info(paramsSummaryLog(workflow, parameters_schema: parameters_schema))
        log.info(paramsSummaryLog(workflow))

        // Validate the parameters using nextflow_schema.json or the schema
        // given via the validation.parametersSchema configuration option
        // TODO if (parameters_schema) { validateParameters(parameters_schema: parameters_schema)
        validateParameters()
    }
    else {
        log.info(paramsSummaryLog(workflow))
    }

    // Check config provided to the pipeline
    valid_config = checkConfigProvided()
    checkProfileProvided(nextflow_cli_args)

    //
    // Create channel from input file provided through params.input
    //
    ch_input = file(input)
    if (isSraId(ch_input)) {
        sraCheckENAMetadataFields(ena_metadata_fields)
    }
    else {
        error('Ids provided via --input not recognised please make sure they are either SRA / ENA / GEO / DDBJ ids!')
    }

    // Read in ids from --input file
    Channel.from(ch_input)
        .splitCsv(header: false, sep: '', strip: true)
        .map { it[0] }
        .unique()
        .set { ch_ids }

    emit:
    ids = ch_ids
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {
    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                [],
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }

        sraCurateSamplesheetWarn()
    }

    workflow.onError {
        log.error("Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting")
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Check if input ids are from the SRA
//
def isSraId(input) {
    def is_sra = false
    def total_ids = 0
    def no_match_ids = []
    def pattern = /^(((SR|ER|DR)[APRSX])|(SAM(N|EA|D))|(PRJ(NA|EB|DB))|(GS[EM]))(\d+)$/
    input.eachLine { line ->
        total_ids += 1
        if (!(line =~ pattern)) {
            no_match_ids << line
        }
    }

    def num_match = total_ids - no_match_ids.size()
    if (num_match > 0) {
        if (num_match == total_ids) {
            is_sra = true
        }
        else {
            error("Mixture of ids provided via --input: ${no_match_ids.join(', ')}\nPlease provide either SRA / ENA / GEO / DDBJ ids!")
        }
    }
    return is_sra
}

//
// Check and validate parameters
//
def sraCheckENAMetadataFields(ena_metadata_fields) {
    // Check minimal ENA fields are provided to download FastQ files
    def valid_ena_metadata_fields = ['run_accession', 'experiment_accession', 'library_layout', 'fastq_ftp', 'fastq_md5']
    def actual_ena_metadata_fields = ena_metadata_fields ? ena_metadata_fields.split(',').collect { it.trim().toLowerCase() } : valid_ena_metadata_fields
    if (!actual_ena_metadata_fields.containsAll(valid_ena_metadata_fields)) {
        error("Invalid option: '${ena_metadata_fields}'. Minimally required fields for '--ena_metadata_fields': '${valid_ena_metadata_fields.join(',')}'")
    }
}
//
// Print a warning after pipeline has completed
//
def sraCurateSamplesheetWarn() {
    log.warn(
        """=============================================================================
  Please double-check the samplesheet that has been auto-created by the pipeline.

  Public databases don't reliably hold information such as strandedness
  information, controls etc

  All of the sample metadata obtained from the ENA has been appended
  as additional columns to help you manually curate the samplesheet before
  running nf-core/other pipelines.
============================================================================="""
    )
}
