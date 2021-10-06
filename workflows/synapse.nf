/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowFetchngs.initialise(params, log)

// Check mandatory parameters
if (params.input) {
    Channel
        .from(file(params.input, checkIfExists: true))
        .splitCsv(header:false, sep:'', strip:true)
        .map { it[0] }
        .unique()
        .set { ch_ids }
} else {
    exit 1, 'Input file with Synapse IDs not specified!'
}

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

include { SYNAPSE_LIST               } from '../modules/local/synapse_list'                 addParams( options: modules['synapse_list']             )
include { SYNAPSE_GET                } from '../modules/local/synapse_get'                  addParams( options: modules['synapse_get']              )
include { SYNAPSE_SHOW               } from '../modules/local/synapse_show'                 addParams( options: modules['synapse_show']             )
include { SYNAPSE_TO_SAMPLESHEET     } from '../modules/local/synapse_to_samplesheet'       addParams( options: modules['synapse_to_samplesheet']   )
include { SYNAPSE_METADATA_MAPPING   } from '../modules/local/synapse_metadata_mapping'     addParams( options: modules['synapse_metadata_mapping'] )
include { SYNAPSE_MERGE_SAMPLESHEET  } from '../modules/local/synapse_merge_samplesheet'    addParams( options: modules['synapse_merge_samplesheet'])
include { GET_SOFTWARE_VERSIONS      } from '../modules/local/get_software_versions'        addParams( options: [publish_files : ['tsv':'']]        )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow SYNAPSE {

    ch_software_versions = Channel.empty()

    // CHANNEL: Stage Synapse Config File
    Channel
        .fromPath(params.synapseconfig)
        .set { ch_synapseConfig }

    // MODULE: Get individual FastQ SynapseIDs from Directory SynapseID(s)
    SYNAPSE_LIST (
        ch_ids,
        ch_synapseConfig
    )
    ch_software_versions = ch_software_versions.mix(SYNAPSE_LIST.out.version.first().ifEmpty(null))

    // CHANNEL: Create channel for FQ SynapseIDs
    SYNAPSE_LIST
        .out
        .synlist_csv
        .splitCsv(header:false, strip:true).flatten()
        .set { ch_samples }

    // MODULE: Download FastQ Files by SynapseID
    SYNAPSE_GET (
        ch_samples,
        ch_synapseConfig
    )
    ch_software_versions = ch_software_versions.mix(SYNAPSE_GET.out.version.first().ifEmpty(null))

    // CHANNEL: Create Read Pairs Channel - Creates format [sampleId, [fastq_1, fastq_2]]
    SYNAPSE_GET
        .out
        .fastq
        .collect().flatten()
        .toSortedList().flatten()
        .map { meta -> 
            def sampleId = meta.name.toString().tokenize('_').get(0)
            [sampleId, meta]
        }
        .groupTuple()
        .set{ ch_read_pairs }

    // MODULE: Download FQ Metadata by SynapseID
    SYNAPSE_SHOW (
        ch_samples,
        ch_synapseConfig
    )
    ch_software_versions = ch_software_versions.mix(SYNAPSE_SHOW.out.version.first().ifEmpty(null))

    // CHANNEL: Clean Metadata
    SYNAPSE_SHOW
        .out
        .metadata
        .splitCsv(strip:true, sep:"=", skip:1)
        .map { it[1] }
        .collate( 6 )
        .set { ch_meta }

    // MODULE: Compile Metadata
    SYNAPSE_METADATA_MAPPING (
        ch_meta
    )

    // MODULE: Create Samplesheet
    SYNAPSE_TO_SAMPLESHEET (
        ch_read_pairs,
        params.strandedness
    )

    // MODULE: Merge Samplesheets
    SYNAPSE_MERGE_SAMPLESHEET (
        SYNAPSE_TO_SAMPLESHEET.out.samplesheet.collect(),
        SYNAPSE_METADATA_MAPPING.out.metasheet.collect()
    )

    // MODULE: Pipeline reporting
    ch_software_versions
        .map { it -> if (it) [ it.baseName, it ] }
        .groupTuple()
        .map { it[1][0] }
        .flatten()
        .collect()
        .set { ch_software_versions }

    // MODULE: Get Software Versions
    GET_SOFTWARE_VERSIONS (
        ch_software_versions.map { it }.collect()
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
    WorkflowFetchngs.curateSamplesheetWarn(log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
