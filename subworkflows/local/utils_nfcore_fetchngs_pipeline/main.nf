//
// Subworkflow with functionality specific to the nf-core/fetchngs pipeline
//

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version             : boolean       // Display version and exit
    validate_params     : boolean       // Validate parameters against the schema at runtime
    monochrome_logs     : boolean       // Do not use coloured log outputs
    nextflow_cli_args   : List<String>  // List of positional nextflow CLI args
    outdir              : String        // The output directory where the results will be saved
    input               : Path          // File containing SRA/ENA/GEO/DDBJ identifiers one per line to download their associated metadata and FastQ files
    ena_metadata_fields : String        // Comma-separated list of ENA metadata fields to fetch before downloading data

    main:

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Auto-detect input id type
    //
    ids = input
        .splitCsv(header:false, sep:'', strip:true)
        .collect { row -> row[0] }
        .toUnique()
    if (!isSraId(ids)) {
        error('Ids provided via --input not recognised please make sure they are either SRA / ENA / GEO / DDBJ ids!')
    }
    if (!sraCheckENAMetadataFields(ena_metadata_fields)) {
        error("Invalid option: '${ena_metadata_fields}'. Minimally required fields for '--ena_metadata_fields': '${valid_ena_metadata_fields.join(',')}'")
    }

    emit:
    ids : List<String>
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           : String    // email address
    email_on_fail   : String    // email address sent on pipeline failure
    plaintext_email : boolean   // Send plain-text email instead of HTML
    outdir          : Path      // Path to output directory where results will be published
    monochrome_logs : boolean   // Disable ANSI colour codes in log output
    hook_url        : String    // hook URL for notifications

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
                monochrome_logs
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }

        sraCurateSamplesheetWarn()
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
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
def isSraId(ids: List<String>) -> boolean {
    def total_ids = 0
    def no_match_ids = []
    def pattern = /^(((SR|ER|DR)[APRSX])|(SAM(N|EA|D))|(PRJ(NA|EB|DB))|(GS[EM]))(\d+)$/
    ids.each { id ->
        total_ids += 1
        if (!(id =~ pattern)) {
            no_match_ids << id
        }
    }

    def num_match = total_ids - no_match_ids.size()
    return num_match > 0 && num_match == total_ids
}

//
// Check and validate parameters
//
def sraCheckENAMetadataFields(ena_metadata_fields: List<String>) -> boolean {
    // Check minimal ENA fields are provided to download FastQ files
    def valid_ena_metadata_fields = ['run_accession', 'experiment_accession', 'library_layout', 'fastq_ftp', 'fastq_md5']
    def actual_ena_metadata_fields = ena_metadata_fields ? ena_metadata_fields.split(',').collect{ it.trim().toLowerCase() } : valid_ena_metadata_fields
    return actual_ena_metadata_fields.containsAll(valid_ena_metadata_fields)
}
//
// Print a warning after pipeline has completed
//
def sraCurateSamplesheetWarn() {
    log.warn "=============================================================================\n" +
        "  Please double-check the samplesheet that has been auto-created by the pipeline.\n\n" +
        "  Public databases don't reliably hold information such as strandedness\n" +
        "  information, controls etc\n\n" +
        "  All of the sample metadata obtained from the ENA has been appended\n" +
        "  as additional columns to help you manually curate the samplesheet before\n" +
        "  running nf-core/other pipelines.\n" +
        "==================================================================================="
}

