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
include { DGMFINDER_ANALYSIS} from '../modules/local/dgmfinder_analysis'


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
            .map { it[0] }
            .unique()
            .set { ch_fastqs }

    } else {
        //
        // SUBWORKFLOW: Download fastqs and associated files via SRA/ftp
        //
        DOWNLOAD_FASTQS ()

        ch_fastqs = DOWNLOAD_FASTQS.out.ch_fastqs

    }

    ch_fastqs.view()

    // if (params.dgmfinder_samplesheet) {
    //     // Read in from dgmfinder_samplesheet
    //     Channel.fromPath(params.dgmfinder_samplesheet)
    //         .splitCSV(
    //             header: false
    //         )
    //         .map { row ->
    //             tuple(
    //                 row[0],         // fastq_id
    //                 file(row[1]),   // fastq_file
    //                 file(row[2])    // anchors_annot
    //             )
    //         }
    //         .set{ ch_fastq_anchors }

    // } else {
    // }

    //
    // MODULE: Run dgmfinder on fastqs
    //
    // DGMFINDER_ANALYSIS (
    //     ch_fastqs,
    //     params.ann_file,
    //     params.kmer_size
    // )
    // DGMFINDER_ANALYSIS.out.fastq_anchors.view()
    // //
    // // SUBWORKFLOW: Run dgmfinder analysis
    // //
    // STRING_STATS (
    //     DGMFINDER_ANALYSIS.out.fastq_anchors
    // )

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
