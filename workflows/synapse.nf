/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Create channel for synapse config
if (params.synapse_config) {
    ch_synapse_config = file(params.synapse_config, checkIfExists: true)
} else {
    exit 1, 'Please provide a Synapse config file for download authentication!'
}

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { SYNAPSE_LIST              } from '../modules/local/synapse_list'
include { SYNAPSE_SHOW              } from '../modules/local/synapse_show'
include { SYNAPSE_GET               } from '../modules/local/synapse_get'
include { SYNAPSE_TO_SAMPLESHEET    } from '../modules/local/synapse_to_samplesheet'
include { SYNAPSE_MERGE_SAMPLESHEET } from '../modules/local/synapse_merge_samplesheet'

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

workflow SYNAPSE {

    take:
    ids // channel: [ ids ]

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
        .map { it -> WorkflowSynapse.synapseShowToMap(it) }
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
        .map { meta, fastq -> [ WorkflowSynapse.sampleNameFromFastQ( fastq , "*{1,2}*"), fastq ] }
        .groupTuple(sort: { it -> it.baseName })
        .set { ch_fastq }

    SYNAPSE_GET
        .out
        .fastq
        .map { meta, fastq -> [ WorkflowSynapse.sampleNameFromFastQ( fastq , "*{1,2}*"), meta.id ] }
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
        params.nf_core_pipeline ?: ''
    )

    //
    // MODULE: Merge samplesheets
    //
    SYNAPSE_MERGE_SAMPLESHEET (
        SYNAPSE_TO_SAMPLESHEET.out.samplesheet.collect{ it[1] }
    )
    ch_versions = ch_versions.mix(SYNAPSE_MERGE_SAMPLESHEET.out.versions)

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
    WorkflowSynapse.curateSamplesheetWarn(log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
