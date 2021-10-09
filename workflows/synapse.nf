/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Read in ids from --input file
Channel
    .from(file(params.input, checkIfExists: true))
    .splitCsv(header:false, sep:'', strip:true)
    .map { it[0] }
    .unique()
    .set { ch_ids }

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

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

include { SYNAPSE_LIST              } from '../modules/local/synapse_list'              addParams( options: modules['synapse_list']              )
include { SYNAPSE_GET               } from '../modules/local/synapse_get'               addParams( options: modules['synapse_get']               )
include { SYNAPSE_SHOW              } from '../modules/local/synapse_show'              addParams( options: modules['synapse_show']              )
include { SYNAPSE_TO_SAMPLESHEET    } from '../modules/local/synapse_to_samplesheet'    addParams( options: modules['synapse_to_samplesheet']    )
include { SYNAPSE_METADATA_MAPPING  } from '../modules/local/synapse_metadata_mapping'  addParams( options: modules['synapse_metadata_mapping']  )
include { SYNAPSE_MERGE_SAMPLESHEET } from '../modules/local/synapse_merge_samplesheet' addParams( options: modules['synapse_merge_samplesheet'] )

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main' addParams( options: [publish_files : ['_versions.yml':'']] )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow SYNAPSE {

    ch_versions = Channel.empty()

    //
    // MODULE: Get individual FastQ synapse ids from directory based synapse ids
    //
    SYNAPSE_LIST (
        ch_ids,
        ch_synapse_config
    )
    ch_versions = ch_versions.mix(SYNAPSE_LIST.out.versions.first())

    // Create channel for FastQ synapse ids
    SYNAPSE_LIST
        .out
        .csv
        .splitCsv(header:false).flatten()
        .set { ch_samples }

    //
    // MODULE: Download FastQs by synapse id
    //
    SYNAPSE_GET (
        ch_samples,
        ch_synapse_config
    )
    ch_versions = ch_versions.mix(SYNAPSE_LIST.out.versions.first())

    // Create read pair channel: [ sampleId, [ fastq_1, fastq_2 ] ]
    SYNAPSE_GET
        .out
        .fastq
        .collect()
        .flatten()
        .toSortedList()
        .flatten()
        .map { meta ->
            def id = meta.name.toString().tokenize('_').get(0)
            [ id, meta ]
        }
        .groupTuple()
        .set { ch_read_pairs }

    //
    // MODULE: Download FastQ metadata by synapse id
    //
    SYNAPSE_SHOW (
        ch_samples,
        ch_synapse_config
    )
    ch_versions = ch_versions.mix(SYNAPSE_LIST.out.versions.first())

    // Clean metadata in channels
    SYNAPSE_SHOW
        .out
        .metadata
        .splitCsv(strip:true, sep:"=", skip:1)
        .map { it[1] }
        .collate( 6 )
        .set { ch_meta }

    //
    // MODULE: Compile metadata
    //
    SYNAPSE_METADATA_MAPPING (
        ch_meta
    )

    //
    // MODULE: Create samplesheet
    //
    SYNAPSE_TO_SAMPLESHEET (
        ch_read_pairs
    )

    //
    // MODULE: Merge samplesheets
    //
    SYNAPSE_MERGE_SAMPLESHEET (
        SYNAPSE_TO_SAMPLESHEET.out.samplesheet.collect(),
        SYNAPSE_METADATA_MAPPING.out.metasheet.collect()
    )
    ch_versions = ch_versions.mix(SYNAPSE_LIST.out.versions.first())

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
    //WorkflowSynapse.curateSamplesheetWarn(log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
