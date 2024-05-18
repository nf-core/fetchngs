//
// Subworkflow with functionality specific to the nf-core/fetchngs pipeline
//

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

include { UTILS_NFVALIDATION_PLUGIN } from '../../nf-core/utils_nfvalidation_plugin'
include { fromSamplesheet           } from 'plugin/nf-validation'
include { paramsSummaryMap          } from 'plugin/nf-validation'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { dashedLine                } from '../../nf-core/utils_nfcore_pipeline'
include { nfCoreLogo                } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { workflowCitation          } from '../../nf-core/utils_nfcore_pipeline'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version             : boolean   // Display version and exit
    help                : boolean   // Display help text
    validate_params     : boolean   // Validate parameters against the schema at runtime
    monochrome_logs     : boolean   // Do not use coloured log outputs
    nextflow_cli_args   : List      // List of positional nextflow CLI args
    outdir              : String    // The output directory where the results will be saved
    input               : String    // File containing SRA/ENA/GEO/DDBJ identifiers one per line to download their associated metadata and FastQ files
    ena_metadata_fields : String    // Comma-separated list of ENA metadata fields to fetch before downloading data

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
    let pre_help_text = nfCoreLogo(monochrome_logs)
    let post_help_text = '\n' + workflowCitation() + '\n' + dashedLine(monochrome_logs)
    let workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input ids.csv --outdir <OUTDIR>"
    UTILS_NFVALIDATION_PLUGIN (
        help,
        workflow_command,
        pre_help_text,
        post_help_text,
        validate_params,
        "params.yml"
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
    let inputPath = file(input)
    if (!isSraId(inputPath))
        error('Ids provided via --input not recognised please make sure they are either SRA / ENA / GEO / DDBJ ids!')
    sraCheckENAMetadataFields(ena_metadata_fields)

    // Read in ids from --input file
    inputPath                                               // Path
        |> Channel.of                                       // Channel<Path>
        |> flatMap { csv ->
            splitCsv(csv, header: false, schema: 'assets/schema_input.yml')
        }                                                   // Channel<String>
        |> unique                                           // Channel<String>
        |> set { ids }                                      // Channel<String>

    emit:
    ids     // Channel<String>
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
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

    let summary_params = paramsSummaryMap(workflow, parameters_schema: "params.yml")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(summary_params, email, email_on_fail, plaintext_email, outdir, monochrome_logs)
        }

        completionSummary(monochrome_logs)

        if (hook_url) {
            imNotification(summary_params, hook_url)
        }

        sraCurateSamplesheetWarn()
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

//
// Check if input ids are from the SRA
//
fn isSraId(input: Path) -> boolean {
    var is_sra = false
    var total_ids = 0
    let no_match_ids = []
    let pattern = /^(((SR|ER|DR)[APRSX])|(SAM(N|EA|D))|(PRJ(NA|EB|DB))|(GS[EM]))(\d+)$/
    input.eachLine { line ->
        total_ids += 1
        if (!(line =~ pattern)) {
            no_match_ids << line
        }
    }

    let num_match = total_ids - no_match_ids.size()
    if (num_match > 0) {
        if (num_match == total_ids) {
            is_sra = true
        } else {
            error("Mixture of ids provided via --input: ${no_match_ids.join(', ')}\nPlease provide either SRA / ENA / GEO / DDBJ ids!")
        }
    }
    return is_sra
}

//
// Check and validate parameters
//
fn sraCheckENAMetadataFields(ena_metadata_fields) {
    // Check minimal ENA fields are provided to download FastQ files
    let valid_ena_metadata_fields = ['run_accession', 'experiment_accession', 'library_layout', 'fastq_ftp', 'fastq_md5']
    let actual_ena_metadata_fields = ena_metadata_fields ? ena_metadata_fields.split(',').collect{ it.trim().toLowerCase() } : valid_ena_metadata_fields
    if (!actual_ena_metadata_fields.containsAll(valid_ena_metadata_fields)) {
        error("Invalid option: '${ena_metadata_fields}'. Minimally required fields for '--ena_metadata_fields': '${valid_ena_metadata_fields.join(',')}'")
    }
}

//
// Print a warning after pipeline has completed
//
fn sraCurateSamplesheetWarn() {
    log.warn "=============================================================================\n" +
        "  Please double-check the samplesheet that has been auto-created by the pipeline.\n\n" +
        "  Public databases don't reliably hold information such as strandedness\n" +
        "  information, controls etc\n\n" +
        "  All of the sample metadata obtained from the ENA has been appended\n" +
        "  as additional columns to help you manually curate the samplesheet before\n" +
        "  running nf-core/other pipelines.\n" +
        "==================================================================================="
}
