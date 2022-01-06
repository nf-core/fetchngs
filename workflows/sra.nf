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

include { PYSRADB                 } from '../modules/local/pysradb'
include { SRA_IDS_TO_RUNINFO      } from '../modules/local/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP      } from '../modules/local/sra_runinfo_to_ftp'
include { SRA_FASTQ_FTP           } from '../modules/local/sra_fastq_ftp'
include { SRA_TO_SAMPLESHEET      } from '../modules/local/sra_to_samplesheet'
include { SRA_MERGE_SAMPLESHEET   } from '../modules/local/sra_merge_samplesheet'
include { MULTIQC_MAPPINGS_CONFIG } from '../modules/local/multiqc_mappings_config'
include { DGMFINDER               } from '../modules/local/dgmfinder'
include { STRING_STATS            } from '../modules/local/string_stats'
include { SIGNIF_ANCHORS          } from '../modules/local/signif_anchors'
include { ADJACENT_ANCHOR         } from '../modules/local/adjacent_anchors'

include { SRA_FASTQ_SRATOOLS      } from '../subworkflows/local/sra_fastq_sratools'

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
    if (!params.fastq_samplesheet) {
        if (params.input_type == 'srp') {
            //
            // MODULE: Get SRR numbers from SRP project
            //
            PYSRADB (
                params.SRP
            )
            PYSRADB.out.ids
                .splitCsv(header:false, sep:'', strip:true)
                .map { it[0] }
                .set { ch_ids }

        } else {
            // Read in ids
            Channel
                .fromPath(params.input)
                .splitCsv(
                    header: false,
                    sep:'',
                    strip: true
                )
                .map { it[0] }
                .unique()
                .set { ch_ids }
        }

        //
        // MODULE: Get SRA run information for public database ids
        //
        SRA_IDS_TO_RUNINFO (
            ch_ids,
            params.ena_metadata_fields ?: ''
        )

        //
        // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
        //
        SRA_RUNINFO_TO_FTP (
            SRA_IDS_TO_RUNINFO.out.tsv
        )

        // Concatenate all metadata files into 1 mega file
        SRA_RUNINFO_TO_FTP.out.tsv
            .map { file ->
                file.text + '\n'
            }
            .collectFile (
                name:       "metadata.tsv",
                storeDir:   "${params.outdir}",
                keepHeader: true,
                skip:       1
            )

        SRA_RUNINFO_TO_FTP.out.tsv
            .splitCsv(
                header: true,
                sep:'\t'
            )
            .map {
                meta ->
                    meta.single_end = meta.single_end.toBoolean()
                    [ meta, [ meta.fastq_1, meta.fastq_2 ] ]
            }
            .unique()
            .branch {
                ftp: it[0].fastq_1  && !params.force_sratools_download
                sra: !it[0].fastq_1 || params.force_sratools_download
            }
            .set { ch_sra_reads }

        //
        // MODULE: If FTP link is provided in run information then download FastQ directly via FTP and validate with md5sums
        //
        SRA_FASTQ_FTP (
            ch_sra_reads.ftp
        )

        //
        // SUBWORKFLOW: Download sequencing reads without FTP links using sra-tools.
        //
        SRA_FASTQ_SRATOOLS (
            ch_sra_reads.sra.map { meta, reads -> [ meta, meta.run_accession ] }
        )

        SRA_FASTQ_FTP.out.fastq
            .mix(SRA_FASTQ_SRATOOLS.out.reads)
            .set{ ch_fastqs }

        //
        // MODULE: Stage FastQ files downloaded by SRA together and auto-create a samplesheet
        //
        SRA_TO_SAMPLESHEET (
            ch_fastqs,
            params.nf_core_pipeline ?: '',
            params.sample_mapping_fields
        )

        //
        // MODULE: Create a merged samplesheet across all samples for the pipeline
        //
        SRA_MERGE_SAMPLESHEET (
            SRA_TO_SAMPLESHEET.out.samplesheet.collect{it[1]},
            SRA_TO_SAMPLESHEET.out.mappings.collect{it[1]}
        )

        ch_fastqs
            .map { file -> file[1]}
            .flatten()
            .set { ch_fastqs_only }

    } else {
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
            .set { ch_fastqs_only }
    }

    //
    // MODULE: Run dgmfinder on fastqs
    //
    DGMFINDER (
        ch_fastqs_only,
        params.ann_file,
        params.kmer_size
    )

    ch_fastq_anchors = DGMFINDER.out.fastq_anchors

    //
    // MODULE: Run post processing on dgmfinder output
    //
    STRING_STATS (
        ch_fastq_anchors
        params.looklength
    )

    //
    // MODULE: Extract significant anchors
    //
    SIGNIF_ANCHORS (
        ch_fastq_anchors,
        params.direction,
        params.q_val
    )

    // Concatenate all significant anchors
    SIGNIF_ANCHORS.out.tsv
        .map { file ->
            file.text + '\n'
        }
        .collectFile (
            name:       "signif_anchors_${params.direction}_qval_${params.q_val}.tsv",
            storeDir:   "${params.outdir}/string_stats"
        )
        .set { ch_signif_anchors }

    //
    // MODULE: Extract adjacent anchors
    //
    ADJACENT_ANCHORS (
        ch_signif_anchors,
        ch_fastq_anchors,
        params.direction,
        params.kmer_size,
        params.adj_dist,
        params.adj_len
    )

    // Concatenate all adjacent anchors
    ADJACENT_ANCHORS.out.tsv
        .map { file ->
            file.text + '\n'
        }
        .collectFile (
            name:       "adjacent_anchors_${params.direction}_qval_${params.q_val}.tsv",

            storeDir:   "${params.outdir}/string_stats"
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
