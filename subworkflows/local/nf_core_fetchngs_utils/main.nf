//
// Subworkflow with functionality specific to the nf-core/fetchngs pipeline
//

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

include { NEXTFLOW_PIPELINE_UTILS; getWorkflowVersion } from '../../nf-core/nextflowpipelineutils/main'
include { NF_VALIDATION_PLUGIN_UTILS                  } from '../../nf-core/nfvalidation_plugin_utils/main.nf'
include { 
    NFCORE_PIPELINE_UTILS; 
    workflowCitation; 
    nfCoreLogo; 
    dashedLine; 
    completionEmail; 
    completionSummary; 
    imNotification 
} from '../../nf-core/nfcore_pipeline_utils'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    main:

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    NEXTFLOW_PIPELINE_UTILS (
        params.version,
        true,
        params.outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    def pre_help_text = nfCoreLogo(getWorkflowVersion())
    def post_help_text = '\n' + workflowCitation() + '\n' + dashedLine()
    def String workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input ids.csv --outdir <OUTDIR>"
    NF_VALIDATION_PLUGIN_UTILS (
        params.help,
        workflow_command,
        pre_help_text,
        post_help_text,
        params.validate_params,
        "nextflow_schema.json"
    )

    //
    // Check config provided to the pipeline
    //
    NFCORE_PIPELINE_UTILS ()

    //
    // Auto-detect input id type
    //
    ch_input = file(params.input)
    def input_type = ''
    if (isSraId(ch_input)) {
        input_type = 'sra'
        sraCheckENAMetadataFields()
    } else if (isSynapseId(ch_input)) {
        input_type = 'synapse'
    } else {
        error('Ids provided via --input not recognised please make sure they are either SRA / ENA / GEO / DDBJ or Synapse ids!')
    }

    if (params.input_type != input_type) {
        error("Ids auto-detected as ${input_type}. Please provide '--input_type ${input_type}' as a parameter to the pipeline!")
    }

    // Read in ids from --input file
    Channel
        .from(ch_input)
        .splitCsv(header:false, sep:'', strip:true)
        .map { it[0] }
        .unique()
        .set { ch_ids }

    emit:
    ids            = ch_ids
    summary_params = NF_VALIDATION_PLUGIN_UTILS.out.summary_params
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    versions       // channel: software tools versions
    input_type     //  string: 'sra' or 'synapse'
    email          //  string: email address
    email_on_fail  //  string: email address sent on pipeline failure
    hook_url       //  string: hook URL for notifications
    summary_params //     map: Groovy map of the parameters used in the pipeline

    main:

    //
    // MODULE: Dump software versions for all tools used in the workflow
    //
    pipeline_version_info = Channel.of("""\"workflow\":
        nextflow: ${workflow.nextflow.version}
        ${workflow.manifest.name}: ${workflow.manifest.version}
    """.stripIndent())

    versions = versions.mix(pipeline_version_info)
    versions.collectFile(name: 'fetchngs_mqc_versions.yml', storeDir: "${params.outdir}/pipeline_info")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(summary_params)
        }

        completionSummary()

        if (hook_url) {
            imNotification(summary_params)
        }

        if (input_type == 'sra') {
            sraCurateSamplesheetWarn()
        } else if (input_type == 'synapse') {
            synapseCurateSamplesheetWarn()
        }
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

//
// Check if input ids are from the SRA
//
def isSraId(input) {
    def is_sra = false
    def total_ids = 0
    def no_match_ids = []
    def pattern = /^(((SR|ER|DR)[APRSX])|(SAM(N|EA|D))|(PRJ(NA|EB|DB))|(GS[EM]))(\d+)$/
    input.eachLine { line ->
        total_ids += 1
        if (!(line =~ pattern)) {
            no_match_ids << line
        }
    }

    def num_match = total_ids - no_match_ids.size()
    if (num_match > 0) {
        if (num_match == total_ids) {
            is_sra = true
        } else {
            error("Mixture of ids provided via --input: ${no_match_ids.join(', ')}\nPlease provide either SRA / ENA / GEO / DDBJ or Synapse ids!")
        }
    }
    return is_sra
}

//
// Check if input ids are from the Synapse platform
//
def isSynapseId(input) {
    def is_synapse = false
    def total_ids = 0
    def no_match_ids = []
    def pattern = /^syn\d{8}$/
    input.eachLine { line ->
        total_ids += 1
        if (!(line =~ pattern)) {
            no_match_ids << line
        }
    }

    def num_match = total_ids - no_match_ids.size()
    if (num_match > 0) {
        if (num_match == total_ids) {
            is_synapse = true
        } else {
            error("Mixture of ids provided via --input: ${no_match_ids.join(', ')}\nPlease provide either SRA / ENA / GEO / DDBJ or Synapse ids!")
        }
    }
    return is_synapse
}

//
// Check and validate parameters
//
def sraCheckENAMetadataFields() {
    // Check minimal ENA fields are provided to download FastQ files
    def valid_ena_metadata_fields = ['run_accession', 'experiment_accession', 'library_layout', 'fastq_ftp', 'fastq_md5']
    def ena_metadata_fields = params.ena_metadata_fields ? params.ena_metadata_fields.split(',').collect{ it.trim().toLowerCase() } : valid_ena_metadata_fields
    if (!ena_metadata_fields.containsAll(valid_ena_metadata_fields)) {
        error("Invalid option: '${params.ena_metadata_fields}'. Minimally required fields for '--ena_metadata_fields': '${valid_ena_metadata_fields.join(',')}'")
    }
}

//
// Print a warning after pipeline has completed
//
def sraCurateSamplesheetWarn() {
    log.warn "=============================================================================\n" +
        "  Please double-check the samplesheet that has been auto-created by the pipeline.\n\n" +
        "  Public databases don't reliably hold information such as strandedness\n" +
        "  information, controls etc\n\n" +
        "  All of the sample metadata obtained from the ENA has been appended\n" +
        "  as additional columns to help you manually curate the samplesheet before\n" +
        "  running nf-core/other pipelines.\n" +
        "==================================================================================="
}

//
// Convert metadata obtained from the 'synapse show' command to a Groovy map
//
def synapseShowToMap(synapse_file) {
    def meta = [:]
    def category = ''
    synapse_file.eachLine { line ->
        def entries = [null, null]
        if (!line.startsWith(' ') && !line.trim().isEmpty()) {
            category = line.tokenize(':')[0]
        } else {
            entries = line.trim().tokenize('=')
        }
        meta["${category}|${entries[0]}"] = entries[1]
    }
    meta.id = meta['properties|id']
    meta.name = meta['properties|name']
    meta.md5 = meta['File|md5']
    return meta.findAll{ it.value != null }
}

//
// Print a warning after pipeline has completed
//
def synapseCurateSamplesheetWarn() {
    log.warn "=============================================================================\n" +
        "  Please double-check the samplesheet that has been auto-created by the pipeline.\n\n" +
        "  Where applicable, default values will be used for sample-specific metadata\n" +
        "  such as strandedness, controls etc as this information is not provided\n" +
        "  in a standardised manner when uploading data to Synapse.\n" +
        "==================================================================================="
}

//
// Obtain Sample ID from File Name
//
def synapseSampleNameFromFastQ(input_file, pattern) {

    def sampleids = ""

    def filePattern = pattern.toString()
    int p = filePattern.lastIndexOf('/')
        if( p != -1 )
            filePattern = filePattern.substring(p+1)

    input_file.each {
        String fileName = input_file.getFileName().toString()

        String indexOfWildcards = filePattern.findIndexOf { it=='*' || it=='?' }
        String indexOfBrackets = filePattern.findIndexOf { it=='{' || it=='[' }
        if( indexOfWildcards==-1 && indexOfBrackets==-1 ) {
            if( fileName == filePattern )
                return actual.getSimpleName()
            throw new IllegalArgumentException("Not a valid file pair globbing pattern: pattern=$filePattern file=$fileName")
        }

        int groupCount = 0
        for( int i=0; i<filePattern.size(); i++ ) {
            def ch = filePattern[i]
            if( ch=='?' || ch=='*' )
                groupCount++
            else if( ch=='{' || ch=='[' )
                break
        }

        def regex = filePattern
                .replace('.','\\.')
                .replace('*','(.*)')
                .replace('?','(.?)')
                .replace('{','(?:')
                .replace('}',')')
                .replace(',','|')

        def matcher = (fileName =~ /$regex/)
        if( matcher.matches() ) {
            int c=Math.min(groupCount, matcher.groupCount())
            int end = c ? matcher.end(c) : ( indexOfBrackets != -1 ? indexOfBrackets : fileName.size() )
            def prefix = fileName.substring(0,end)
            while(prefix.endsWith('-') || prefix.endsWith('_') || prefix.endsWith('.') )
                prefix=prefix[0..-2]
            sampleids = prefix
        }
    }
    return sampleids
}
