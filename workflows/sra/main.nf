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
WorkflowSra.initialise(params, valid_params)

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { SRA_IDS_TO_RUNINFO      } from '../../modules/local/sra_ids_to_runinfo/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP      } from '../../modules/local/sra_runinfo_to_ftp/sra_runinfo_to_ftp'
include { SRA_FASTQ_FTP           } from '../../modules/local/sra_fastq_ftp/sra_fastq_ftp'
include { SRA_TO_SAMPLESHEET      } from '../../modules/local/sra_to_samplesheet/sra_to_samplesheet'
include { SRA_MERGE_SAMPLESHEET   } from '../../modules/local/sra_merge_samplesheet/sra_merge_samplesheet'
include { MULTIQC_MAPPINGS_CONFIG } from '../../modules/local/multiqc_mappings_config/multiqc_mappings_config'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../../modules/nf-core/custom/dumpsoftwareversions/main'

include { FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS } from '../../subworkflows/nf-core/fastq_download_prefetch_fasterqdump_sratools/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow SRA {

    take:
    ids // channel: [ ids ]

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Get SRA run information for public database ids
    //
    SRA_IDS_TO_RUNINFO (
        ids,
        params.ena_metadata_fields ?: ''
    )
    ch_versions = ch_versions.mix(SRA_IDS_TO_RUNINFO.out.versions.first())

    //
    // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
    //
    SRA_RUNINFO_TO_FTP (
        SRA_IDS_TO_RUNINFO.out.tsv
    )
    ch_versions = ch_versions.mix(SRA_RUNINFO_TO_FTP.out.versions.first())

    SRA_RUNINFO_TO_FTP
        .out
        .tsv
        .splitCsv(header:true, sep:'\t')
        .map {
            meta ->
                def meta_clone = meta.clone()
                meta_clone.single_end = meta_clone.single_end.toBoolean()
                return meta_clone
        }
        .unique()
        .set { ch_sra_metadata }
    ch_versions = ch_versions.mix(SRA_RUNINFO_TO_FTP.out.versions.first())

    if (!params.skip_fastq_download) {

        ch_sra_metadata
            .map { 
                meta -> 
                    [ meta, [ meta.fastq_1, meta.fastq_2 ] ] 
            }
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
        ch_versions = ch_versions.mix(SRA_FASTQ_FTP.out.versions.first())

        //
        // SUBWORKFLOW: Download sequencing reads without FTP links using sra-tools.
        //
        FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS (
            ch_sra_reads.sra.map { meta, reads -> [ meta, meta.run_accession ] },
            params.dbgap_key ? file(params.dbgap_key, checkIfExists: true) : []
        )
        ch_versions = ch_versions.mix(FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS.out.versions.first())

        SRA_FASTQ_FTP
            .out
            .fastq
            .mix(FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS.out.reads)
            .map { 
                meta, fastq ->
                    def reads = fastq instanceof List ? fastq.flatten() : [ fastq ]
                    def meta_clone = meta.clone()
                    meta_clone.fastq_1 = reads[0] ? "${params.outdir}/fastq/${reads[0].getName()}" : ''
                    meta_clone.fastq_2 = reads[1] && !meta.single_end ? "${params.outdir}/fastq/${reads[1].getName()}" : ''
                    return meta_clone
            }
            .set { ch_sra_metadata }
    }

    //
    // MODULE: Stage FastQ files downloaded by SRA together and auto-create a samplesheet
    //
    SRA_TO_SAMPLESHEET (
        ch_sra_metadata,
        params.nf_core_pipeline ?: '',
        params.nf_core_rnaseq_strandedness ?: 'auto',
        params.sample_mapping_fields
    )

    //
    // MODULE: Create a merged samplesheet across all samples for the pipeline
    //
    SRA_MERGE_SAMPLESHEET (
        SRA_TO_SAMPLESHEET.out.samplesheet.collect{it[1]},
        SRA_TO_SAMPLESHEET.out.mappings.collect{it[1]}
    )
    ch_versions = ch_versions.mix(SRA_MERGE_SAMPLESHEET.out.versions)

    //
    // MODULE: Create a MutiQC config file with sample name mappings
    //
    if (params.sample_mapping_fields) {
        MULTIQC_MAPPINGS_CONFIG (
            SRA_MERGE_SAMPLESHEET.out.mappings
        )
        ch_versions = ch_versions.mix(MULTIQC_MAPPINGS_CONFIG.out.versions)
    }

    //
    // MODULE: Dump software versions for all tools used in the workflow
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
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
