/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def valid_params = [
    ena_metadata_fields : ['run_accession', 'experiment_accession', 'library_layout', 'fastq_ftp', 'fastq_md5']
]

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowSra.initialise(params, log, valid_params)

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Modules
include { PYSRADB           } from '../modules/local/pysradb'

// Subworkflows
include { DOWNLOAD_FASTQS   } from '../subworkflows/local/download_fastqs'
include { DGMFINDER         } from '../subworkflows/local/dgmfinder'
include { STRING_STATS      } from '../subworkflows/local/string_stats'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow SRA {

    ch_versions = Channel.empty()

    // Only run string_stats
    if (params.dgmfinder_samplesheet) {
        // Make channel of fastqs
        Channel.fromPath(params.dgmfinder_samplesheet)
            .splitCsv(
                header: false
            )
            .map { row ->
                file(row[1])
            }
            .set{ ch_fastqs }

        // Read in from dgmfinder_samplesheet
        Channel.fromPath(params.dgmfinder_samplesheet)
            .splitCsv(
                header: false
            )
            .map { row ->
                tuple(
                    row[0],         // fastq_id
                    file(row[1]),   // fastq_file
                    file(row[2])    // anchors_annot
                )
            }
            .set{ ch_dgmfinder }

    } else {

        // Read in fastqs from samplesheet or download via SRA
        if (params.fastq_samplesheet) {
            // Read in fastqs from samplesheet
            Channel
                .fromPath(params.fastq_samplesheet)
                .splitCsv(
                    header: false,
                    sep:'',
                    strip: true
                )
                .map { file(it[0]) }
                .unique()
                .set { ch_fastqs }

        } else {
            //
            // SUBWORKFLOW: Download fastqs and associated files via SRA/ftp
            //
            DOWNLOAD_FASTQS ()

            ch_fastqs = DOWNLOAD_FASTQS.out.fastqs

        }

        //
        // SUBWORKFLOW: Run dgmfinder
        //
        DGMFINDER (
            ch_fastqs
        )

        ch_dgmfinder = DGMFINDER.out.fastq_anchors

    }

    // Get min number of reads for string_stats
    if (params.num_reads) {
        num_input_lines = params.num_reads
    } else {
        // Get the number of reads in the smallest fastq file
        ch_fastqs
            .map { file ->
                file.countFastq()
            }
            .set{ ch_fastqs_numReads }

        num_input_lines = ch_fastqs_numReads.min()
    }

    //
    // SUBWORKFLOW: Run string_stats
    //
    STRING_STATS (
        ch_dgmfinder,
        num_input_lines
    )
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
========================================================================================
    THE END
========================================================================================
*/
