/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC_MAPPINGS_CONFIG } from '../../modules/local/multiqc_mappings_config'
include { SRA_FASTQ_FTP           } from '../../modules/local/sra_fastq_ftp'
include { SRA_IDS_TO_RUNINFO      } from '../../modules/local/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP      } from '../../modules/local/sra_runinfo_to_ftp'
include { ASPERA_CLI              } from '../../modules/local/aspera_cli'
include { SRA_TO_SAMPLESHEET      } from '../../modules/local/sra_to_samplesheet'
include { softwareVersionsToYAML  } from '../../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS } from '../../subworkflows/nf-core/fastq_download_prefetch_fasterqdump_sratools'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SRA {

    take:
    ids                         // channel: [ ids ]
    ena_metadata_fields         // string
    sample_mapping_fields       // string
    nf_core_pipeline            // string
    nf_core_rnaseq_strandedness // string
    download_method             // enum: 'aspera' | 'ftp' | 'sratools'
    skip_fastq_download         // boolean
    dbgap_key                   // string
    aspera_cli_args             // string
    sra_fastq_ftp_args          // string
    sratools_fasterqdump_args   // string
    sratools_pigz_args          // string
    outdir                      // string

    main:
    //
    // MODULE: Get SRA run information for public database ids
    //
    SRA_IDS_TO_RUNINFO (
        ids,
        ena_metadata_fields
    )

    //
    // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
    //
    SRA_RUNINFO_TO_FTP (
        SRA_IDS_TO_RUNINFO.out.tsv
    )

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

    if (!skip_fastq_download) {

        ch_sra_metadata
            .branch {
                meta ->
                    def method = 'ftp'
                    // meta.fastq_aspera is a metadata string with ENA fasp links supported by Aspera
                        // For single-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/ERR116/006/ERR1160846/ERR1160846.fastq.gz'
                        // For paired-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_1.fastq.gz;fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_2.fastq.gz'
                    if (meta.fastq_aspera && download_method == 'aspera') {
                        method = 'aspera'
                    }
                    if ((!meta.fastq_aspera && !meta.fastq_1) || download_method == 'sratools') {
                        method = 'sratools'
                    }

                    aspera: method == 'aspera'
                        return [ meta, meta.fastq_aspera.tokenize(';').take(2) ]
                    ftp: method == 'ftp'
                        return [ meta, [ meta.fastq_1, meta.fastq_2 ] ]
                    sratools: method == 'sratools'
                        return [ meta, meta.run_accession ]
            }
            .set { ch_sra_reads }

        //
        // MODULE: If FTP link is provided in run information then download FastQ directly via FTP and validate with md5sums
        //
        SRA_FASTQ_FTP (
            ch_sra_reads.ftp,
            sra_fastq_ftp_args
        )

        //
        // SUBWORKFLOW: Download sequencing reads without FTP links using sra-tools.
        //
        FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS (
            ch_sra_reads.sratools,
            dbgap_key ? file(dbgap_key, checkIfExists: true) : [],
            sratools_fasterqdump_args,
            sratools_pigz_args
        )

        //
        // MODULE: If Aspera link is provided in run information then download FastQ directly via Aspera CLI and validate with md5sums
        //
        ASPERA_CLI (
            ch_sra_reads.aspera,
            'era-fasp',
            aspera_cli_args
        )

        // Isolate FASTQ channel which will be added to emit block
        SRA_FASTQ_FTP
            .out
            .fastq
            .mix(FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS.out.reads)
            .mix(ASPERA_CLI.out.fastq)
            .tap { ch_fastq }
            .map {
                meta, fastq ->
                    def reads = fastq instanceof List ? fastq.flatten() : [ fastq ]
                    def meta_clone = meta.clone()

                    meta_clone.fastq_1 = reads[0] ? "${outdir}/fastq/${reads[0].getName()}" : ''
                    meta_clone.fastq_2 = reads[1] && !meta.single_end ? "${outdir}/fastq/${reads[1].getName()}" : ''

                    return meta_clone
            }
            .set { ch_sra_metadata }
    }

    //
    // MODULE: Stage FastQ files downloaded by SRA together and auto-create a samplesheet
    //
    SRA_TO_SAMPLESHEET (
        ch_sra_metadata,
        nf_core_pipeline,
        nf_core_rnaseq_strandedness,
        sample_mapping_fields
    )

    // Merge samplesheets and mapping files across all samples
    SRA_TO_SAMPLESHEET
        .out
        .samplesheet
        .map { it[1] }
        .collectFile(name:'tmp_samplesheet.csv', newLine: true, keepHeader: true, sort: { it.baseName })
        .map { it.text.tokenize('\n').join('\n') }
        .collectFile(name:'samplesheet.csv')
        .set { ch_samplesheet }

    SRA_TO_SAMPLESHEET
        .out
        .mappings
        .map { it[1] }
        .collectFile(name:'tmp_id_mappings.csv', newLine: true, keepHeader: true, sort: { it.baseName })
        .map { it.text.tokenize('\n').join('\n') }
        .collectFile(name:'id_mappings.csv')
        .set { ch_mappings }

    //
    // MODULE: Create a MutiQC config file with sample name mappings
    //
    ch_sample_mappings_yml = Channel.empty()
    if (sample_mapping_fields) {
        MULTIQC_MAPPINGS_CONFIG (
            ch_mappings
        )
        ch_sample_mappings_yml = MULTIQC_MAPPINGS_CONFIG.out.yml
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(Channel.topic('versions'))
        .collectFile(name: 'nf_core_fetchngs_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_versions_yml }

    emit:
    samplesheet     = ch_samplesheet
    mappings        = ch_mappings
    sample_mappings = ch_sample_mappings_yml
    sra_metadata    = ch_sra_metadata

    publish:
    ch_fastq                    >> 'fastq'
    ASPERA_CLI.out.md5          >> 'fastq/md5'
    SRA_FASTQ_FTP.out.md5       >> 'fastq/md5'
    SRA_RUNINFO_TO_FTP.out.tsv  >> 'metadata'
    ch_versions_yml             >> 'pipeline_info'
    ch_samplesheet              >> 'samplesheet'
    ch_mappings                 >> 'samplesheet'
    ch_sample_mappings_yml      >> 'samplesheet'
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
