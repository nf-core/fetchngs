//
// Subworkflow with functionality specific to the nf-core/fetchngs pipeline
//

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

include { checkCondaChannels       } from 'plugin/nf-core-utils'
include { checkConfigProvided      } from 'plugin/nf-core-utils'
include { checkProfileProvided     } from 'plugin/nf-core-utils'
include { completionEmail          } from 'plugin/nf-core-utils'
include { completionSummary        } from 'plugin/nf-core-utils'
include { dumpParametersToJSON     } from 'plugin/nf-core-utils'
include { getWorkflowVersion       } from 'plugin/nf-core-utils'

include { paramsHelp               } from 'plugin/nf-schema'
include { paramsSummaryLog         } from 'plugin/nf-schema'
include { paramsSummaryMap         } from 'plugin/nf-schema'
include { samplesheetToList        } from 'plugin/nf-schema'
include { validateParameters       } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {
    take:
    version // boolean: Display version and exit
    validate_params // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir //  string: The output directory where the results will be saved
    input //  string: Path to input samplesheet
    ena_metadata_fields //  string: Comma-separated list of ENA metadata fields to fetch before downloading data
    help // boolean: Display help message and exit
    help_full // boolean: Show the full help message
    show_hidden // boolean: Show hidden parameters in the help message

    main:

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    if (version) {
        log.info("${workflow.manifest.name} ${getWorkflowVersion()}")
        System.exit(0)
    }

    if (outdir) {
        dumpParametersToJSON(outdir, params)
    }

    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        checkCondaChannels()
    }

    //
    // Validate parameters and generate parameter summary to stdout
    //

    def before_text = ""
    def after_text = ""
    before_text = """
-\033[2m----------------------------------------------------\033[0m-
                                    \033[0;32m,--.\033[0;30m/\033[0;32m,-.\033[0m
\033[0;34m        ___     __   __   __   ___     \033[0;32m/,-._.--~\'\033[0m
\033[0;34m  |\\ | |__  __ /  ` /  \\ |__) |__         \033[0;33m}  {\033[0m
\033[0;34m  | \\| |       \\__, \\__/ |  \\ |___     \033[0;32m\\`-._,-`-,\033[0m
                                    \033[0;32m`._,._,\'\033[0m
\033[0;35m  nf-core/fetchngs ${workflow.manifest.version}\033[0m
-\033[2m----------------------------------------------------\033[0m-
"""
    after_text = """${workflow.manifest.doi ? "\n* The pipeline\n" : ""}${workflow.manifest.doi.tokenize(",").collect { doi -> "    https://doi.org/${doi.trim().replace('https://doi.org/', '')}" }.join("\n")}${workflow.manifest.doi ? "\n" : ""}
* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/nf-core/fetchngs/blob/master/CITATIONS.md
"""
    if (monochrome_logs) {
        before_text = before_text.replaceAll(/\033\[[0-9;]*m/, '')
    }

    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"

    if (help || help_full) {
        help_options = [
            beforeText: before_text,
            afterText: after_text,
            command: command,
            showHidden: show_hidden,
            fullHelp: help_full,
        ]
        log.info(
            paramsHelp(
                help_options,
                (help instanceof String && help != "true") ? help : "",
            )
        )
        exit(0)
    }

    checkProfileProvided(nextflow_cli_args)

    log.info(before_text)
    log.info(paramsSummaryLog([:], workflow))
    log.info(after_text)

    if (validate_params) {
        validateParameters([:])
    }

    //
    // Check config provided to the pipeline
    //
    checkConfigProvided()

    //
    // Create channel from input file provided through params.input
    //
    if (isSraId(file(input))) {
        sraCheckENAMetadataFields(ena_metadata_fields)
    }
    else {
        error('Ids provided via --input not recognised please make sure they are either SRA / ENA / GEO / DDBJ ids!')
    }

    // Read in ids from --input file
    ch_ids = channel.of(file(input))
        .splitCsv(header: false, sep: '', strip: true)
        .map { row -> row[0] }
        .unique()

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
    email //  string: email address
    email_on_fail //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output

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
        sraCurateSamplesheetWarn()
    }

    workflow.onError {
        log.error("Pipeline failed. Please refer to troubleshooting docs for common issues: https://nf-co.re/docs/running/troubleshooting")
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
    def actual_ena_metadata_fields = ena_metadata_fields ? ena_metadata_fields.split(',').collect { field -> field.trim().toLowerCase() } : valid_ena_metadata_fields
    if (!actual_ena_metadata_fields.containsAll(valid_ena_metadata_fields)) {
        error("Invalid option: '${ena_metadata_fields}'. Minimally required fields for '--ena_metadata_fields': '${valid_ena_metadata_fields.join(',')}'")
    }
}

//
// Print a warning after pipeline has completed
//
def sraCurateSamplesheetWarn() {
    log.warn(
        "=============================================================================\n" + "  Please double-check the samplesheet that has been auto-created by the pipeline.\n\n" + "  Public databases don't reliably hold information such as strandedness\n" + "  information, controls etc\n\n" + "  All of the sample metadata obtained from the ENA has been appended\n" + "  as additional columns to help you manually curate the samplesheet before\n" + "  running nf-core/other pipelines.\n" + "==================================================================================="
    )
}
