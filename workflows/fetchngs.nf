/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ASPERA_CLI                                   } from '../modules/local/aspera_cli'
include { MULTIQC_MAPPINGS_CONFIG                      } from '../modules/local/multiqc_mappings_config'
include { SRA_FASTQ_FTP                                } from '../modules/local/sra_fastq_ftp'
include { SRA_IDS_TO_RUNINFO                           } from '../modules/local/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP                           } from '../modules/local/sra_runinfo_to_ftp'
include { CHANNEL_SRA_CREATE_CSV                       } from '../subworkflows/local/channel_sra_create_csv'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQDL                                      } from '../modules/nf-core/fastqdl'
include { FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS } from '../subworkflows/nf-core/fastq_download_prefetch_fasterqdump_sratools'
include { softwareVersionsToYAML                       } from '../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FETCHNGS {
    take:
    ids // channel: [ ids ]
    outdir

    main:

    def ch_versions = channel.empty()

    //
    // MODULE: Get SRA run information for public database ids
    //
    SRA_IDS_TO_RUNINFO(
        ids,
        params.ena_metadata_fields ?: '',
    )

    //
    // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
    //
    SRA_RUNINFO_TO_FTP(
        SRA_IDS_TO_RUNINFO.out.tsv
    )

    SRA_RUNINFO_TO_FTP.out.tsv
        .filter { row -> row.size() > 0 }
        .splitCsv(header: true, sep: '\t')
        .map { meta ->
            def meta_clone = meta.clone()
            meta_clone.single_end = meta_clone.single_end.toBoolean()
            return meta_clone
        }
        .unique()
        .set { ch_sra_metadata }

    if (!params.skip_fastq_download) {

        ch_sra_metadata
            .branch { meta ->
                def download_method = 'ftp'
                // meta.fastq_aspera is a metadata string with ENA fasp links supported by Aspera
                // For single-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/ERR116/006/ERR1160846/ERR1160846.fastq.gz'
                // For paired-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_1.fastq.gz;fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_2.fastq.gz'
                if (meta.fastq_aspera && params.download_method == 'aspera') {
                    download_method = 'aspera'
                }
                if (params.download_method == 'fastq-dl') {
                    download_method = 'fastq-dl'
                }
                if ((!meta.fastq_aspera && !meta.fastq_1) || params.download_method == 'sratools') {
                    download_method = 'sratools'
                }
                aspera: download_method == 'aspera'
                return [meta, meta.fastq_aspera.tokenize(';').take(2)]
                fastqdl: download_method == 'fastq-dl'
                return [meta, meta.run_accession]
                ftp: download_method == 'ftp'
                return [meta, [meta.fastq_1, meta.fastq_2]]
                sratools: download_method == 'sratools'
                return [meta, meta.run_accession]
            }
            .set { ch_sra_reads }

        //
        // MODULE: If FTP link is provided in run information then download FastQ directly via FTP and validate with md5sums
        //
        SRA_FASTQ_FTP(
            ch_sra_reads.ftp
        )

        //
        // SUBWORKFLOW: Download sequencing reads without FTP links using sra-tools.
        //
        FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS(
            ch_sra_reads.sratools,
            params.dbgap_key ? file(params.dbgap_key, checkIfExists: true) : [],
        )

        //
        // MODULE: If Aspera link is provided in run information then download FastQ directly via Aspera CLI and validate with md5sums
        //
        ASPERA_CLI(
            ch_sra_reads.aspera,
            'era-fasp',
        )

        FASTQDL(
            ch_sra_reads.fastqdl
        )

        // Isolate FASTQ channel which will be added to emit block
        SRA_FASTQ_FTP.out.fastq
            .mix(FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS.out.reads)
            .mix(ASPERA_CLI.out.fastq)
            .mix(FASTQDL.out.fastq)
            .map { meta, fastq ->
                def reads = fastq instanceof List ? fastq.flatten() : [fastq]
                def meta_clone = meta.clone()

                meta_clone.fastq_1 = reads[0] ? "${outdir}/fastq/${reads[0].getName()}" : ''
                meta_clone.fastq_2 = reads[1] && !meta.single_end ? "${outdir}/fastq/${reads[1].getName()}" : ''

                return meta_clone
            }
            .set { ch_sra_metadata }
    }

    //
    // SUBWORKFLOW: Stage FastQ files downloaded by SRA together and auto-create a samplesheet
    //
    CHANNEL_SRA_CREATE_CSV(
        ch_sra_metadata,
        params.nf_core_pipeline ?: '',
        params.nf_core_rnaseq_strandedness ?: 'auto',
        params.sample_mapping_fields,
        outdir,
    )

    ch_samplesheet = CHANNEL_SRA_CREATE_CSV.out.samplesheet
    ch_mappings = CHANNEL_SRA_CREATE_CSV.out.mappings

    //
    // MODULE: Create a MutiQC config file with sample name mappings
    //
    MULTIQC_MAPPINGS_CONFIG(ch_mappings.filter { params.sample_mapping_fields })
    ch_sample_mappings_yml = MULTIQC_MAPPINGS_CONFIG.out.yml

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_' + 'fetchngs_software_' + 'versions.yml',
            sort: true,
            newLine: true,
        )

    emit:
    samplesheet     = ch_samplesheet
    mappings        = ch_mappings
    sample_mappings = ch_sample_mappings_yml
    sra_metadata    = ch_sra_metadata
    versions        = ch_collated_versions
}
