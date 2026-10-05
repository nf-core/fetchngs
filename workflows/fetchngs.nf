/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC_MAPPINGS_CONFIG } from '../modules/local/multiqc_mappings_config'
include { FETCH_SRA               } from '../subworkflows/local/fetch_sra'
include { SAMPLESHEET_WRITER      } from '../subworkflows/local/samplesheet_writer'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { softwareVersionsToYAML } from 'plugin/nf-core-utils'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FETCHNGS {
    take:
    ids // channel: [ ids ]
    outdir
    dbgap_key
    download_method
    ena_metadata_fields
    nf_core_pipeline
    nf_core_rnaseq_strandedness
    sample_mapping_fields
    skip_fastq_download

    main:

    //
    // Route each id to the subworkflow for its repository.
    // To add a repository: add a branch here, call its FETCH_<REPOSITORY>
    // subworkflow below and mix its samplesheet_rows into ch_samplesheet_rows.
    //
    ch_ids = ids.branch { _id ->
        sra: true
    }

    //
    // SUBWORKFLOW: Download FastQ files and metadata for SRA / ENA / DDBJ / GEO ids
    //
    FETCH_SRA(
        ch_ids.sra,
        outdir,
        dbgap_key,
        download_method,
        ena_metadata_fields,
        skip_fastq_download,
    )

    ch_samplesheet_rows = channel.empty()
        .mix(FETCH_SRA.out.samplesheet_rows)

    //
    // SUBWORKFLOW: Write the samplesheet and id mappings for all repositories
    //
    SAMPLESHEET_WRITER(ch_samplesheet_rows, nf_core_pipeline, nf_core_rnaseq_strandedness, sample_mapping_fields, outdir)

    ch_samplesheet = SAMPLESHEET_WRITER.out.samplesheet
    ch_mappings = SAMPLESHEET_WRITER.out.mappings

    //
    // MODULE: Create a MutiQC config file with sample name mappings
    //
    MULTIQC_MAPPINGS_CONFIG(ch_mappings.filter { sample_mapping_fields })
    ch_sample_mappings_yml = MULTIQC_MAPPINGS_CONFIG.out.yml

    //
    // Collate and save software versions
    //
    def ch_collated_versions = softwareVersionsToYAML(
        softwareVersions: channel.topic("versions"),
        nextflowVersion: workflow.nextflow.version,
    ).collectFile(
        storeDir: "${outdir}/pipeline_info",
        name: 'nf_core_' + 'fetchngs_software_' + 'versions.yml',
        sort: true,
        newLine: true,
    )

    emit:
    samplesheet     = ch_samplesheet
    mappings        = ch_mappings
    sample_mappings = ch_sample_mappings_yml
    sra_metadata    = FETCH_SRA.out.metadata
    versions        = ch_collated_versions
}
