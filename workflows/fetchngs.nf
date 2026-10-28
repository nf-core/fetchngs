/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC_MAPPINGS_CONFIG                      } from '../modules/local/multiqc_mappings_config'
include { CHANNEL_SRA_CREATE_CSV                       } from '../subworkflows/local/channel_sra_create_csv'
include { SRA_FETCH_FASTQ                              } from '../subworkflows/local/sra_fetch_fastq'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { softwareVersionsToYAML                       } from 'plugin/nf-core-utils'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FETCHNGS {
    take:
    ids // channel: [ val(source), val(id) ]
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
    // Route each id to the subworkflow for its source
    //
    ch_ids = ids.branch { source, id ->
        sra: source == 'sra'
            return id
        unknown: true
    }

    ch_ids.unknown
        .collect(flat: false)
        .subscribe { unknown ->
            error("No subworkflow to fetch these ids:\n" + unknown.collect { source, id -> "  ${id} (source '${source}')" }.join('\n'))
        }

    //
    // SUBWORKFLOW: Get run metadata and download FastQ files for SRA / ENA / DDBJ / GEO ids
    //
    SRA_FETCH_FASTQ(ch_ids.sra, outdir, dbgap_key, download_method, ena_metadata_fields, skip_fastq_download)
    ch_sra_metadata = SRA_FETCH_FASTQ.out.metadata

    //
    // SUBWORKFLOW: Stage FastQ files downloaded by SRA together and auto-create a samplesheet
    //
    CHANNEL_SRA_CREATE_CSV(ch_sra_metadata, nf_core_pipeline, nf_core_rnaseq_strandedness, sample_mapping_fields, outdir)

    ch_samplesheet = CHANNEL_SRA_CREATE_CSV.out.samplesheet
    ch_mappings = CHANNEL_SRA_CREATE_CSV.out.mappings

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
    sra_metadata    = ch_sra_metadata
    versions        = ch_collated_versions
}
