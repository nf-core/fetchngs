/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SYNAPSE_LIST              } from '../../modules/local/synapse_list'
include { SYNAPSE_SHOW              } from '../../modules/local/synapse_show'
include { SYNAPSE_GET               } from '../../modules/local/synapse_get'
include { SYNAPSE_TO_SAMPLESHEET    } from '../../modules/local/synapse_to_samplesheet'
include { SYNAPSE_MERGE_SAMPLESHEET } from '../../modules/local/synapse_merge_samplesheet'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SYNAPSE {

    take:
    ids               // channel: [ ids ]
    ch_synapse_config // channel: [ synapse_config ]

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Expand synapse ids for individual FastQ files
    //
    SYNAPSE_LIST (
        ids,
        ch_synapse_config
    )
    ch_versions = ch_versions.mix(SYNAPSE_LIST.out.versions.first())

    // Create channel for FastQ synapse ids
    SYNAPSE_LIST
        .out
        .txt
        .splitCsv(header:false, sep:' ')
        .map { it[0] }
        .unique()
        .set { ch_samples }

    //
    // MODULE: Download metadata for each synapse id
    //
    SYNAPSE_SHOW (
        ch_samples,
        ch_synapse_config
    )
    ch_versions = ch_versions.mix(SYNAPSE_SHOW.out.versions.first())

    // Get metadata into channels
    SYNAPSE_SHOW
        .out
        .metadata
        .map { it -> WorkflowMain.synapseShowToMap(it) }
        .set { ch_samples_meta }

    //
    // MODULE: Download FastQs by synapse id
    //
    SYNAPSE_GET (
        ch_samples_meta,
        ch_synapse_config
    )
    ch_versions = ch_versions.mix(SYNAPSE_GET.out.versions.first())

    // Combine channels for PE/SE FastQs: [ [ id:SRR6357070, synapse_ids:syn26240474;syn26240477 ], [ fastq_1, fastq_2 ] ]
    SYNAPSE_GET
        .out
        .fastq
        .map { meta, fastq -> [ WorkflowMain.synapseSampleNameFromFastQ( fastq , "*{1,2}*"), fastq ] }
        .groupTuple(sort: { it -> it.baseName })
        .set { ch_fastq }

    SYNAPSE_GET
        .out
        .fastq
        .map { meta, fastq -> [ WorkflowMain.synapseSampleNameFromFastQ( fastq , "*{1,2}*"), meta.id ] }
        .groupTuple()
        .join(ch_fastq)
        .map { id, synids, fastq ->
            def meta = [ id:id, synapse_ids:synids.join(';') ]
            [ meta, fastq ]
        }
        .set { ch_fastq }

    //
    // MODULE: Create samplesheet per sample
    //
    SYNAPSE_TO_SAMPLESHEET (
        ch_fastq,
        params.nf_core_pipeline ?: '',
        params.nf_core_rnaseq_strandedness ?: 'auto'
    )

    //
    // MODULE: Merge samplesheets
    //
    SYNAPSE_MERGE_SAMPLESHEET (
        SYNAPSE_TO_SAMPLESHEET.out.samplesheet.collect{ it[1] }
    )
    ch_versions = ch_versions.mix(SYNAPSE_MERGE_SAMPLESHEET.out.versions)

    emit:
    fastq       = ch_fastq
    samplesheet = SYNAPSE_MERGE_SAMPLESHEET.out.samplesheet
    versions    = ch_versions.unique()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
