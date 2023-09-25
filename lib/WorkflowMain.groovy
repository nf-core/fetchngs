//
// This file holds several functions specific to the main.nf workflow in the nf-core/fetchngs pipeline
//

import nextflow.Nextflow

class WorkflowMain {

    //
    // Citation string for pipeline
    //
    public static String citation(workflow) {
        return "If you use ${workflow.manifest.name} for your analysis please cite:\n\n" +
            "* The pipeline\n" +
            "  https://doi.org/10.5281/zenodo.5070524\n\n" +
            "* The nf-core framework\n" +
            "  https://doi.org/10.1038/s41587-020-0439-x\n\n" +
            "* Software dependencies\n" +
            "  https://github.com/${workflow.manifest.name}/blob/master/CITATIONS.md"
    }


    //
    // Validate parameters and print summary to screen
    //
    public static void initialise(workflow, params, log) {

        // Print workflow version and exit on --version
        if (params.version) {
            String workflow_version = NfcoreTemplate.version(workflow)
            log.info "${workflow.manifest.name} ${workflow_version}"
            System.exit(0)
        }

        // Check that a -profile or Nextflow config has been provided to run the pipeline
        NfcoreTemplate.checkConfigProvided(workflow, log)

        // Check that conda channels are set-up correctly
        if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
            Utils.checkCondaChannels(log)
        }

        // Check AWS batch settings
        NfcoreTemplate.awsBatch(workflow, params)

        // Check input has been provided
        if (!params.input) {
            Nextflow.error("Please provide an input file containing ids to the pipeline - one per line e.g. '--input ids.csv'")
        }

        // Check valid input_type has been provided
        def input_types = ['sra', 'synapse']
        if (!input_types.contains(params.input_type)) {
            Nextflow.error("Invalid option: '${params.input_type}'. Valid options for '--input_type': ${input_types.join(', ')}.")
        }
    }

    // Check if input ids are from the SRA
    public static Boolean isSraId(input) {
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
                Nextflow.error("Mixture of ids provided via --input: ${no_match_ids.join(', ')}\nPlease provide either SRA / ENA / GEO / DDBJ or Synapse ids!")
            }
        }
        return is_sra
    }

    // Check if input ids are from the Synapse platform
    public static Boolean isSynapseId(input) {
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
                Nextflow.error("Mixture of ids provided via --input: ${no_match_ids.join(', ')}\nPlease provide either SRA / ENA / GEO / DDBJ or Synapse ids!")
            }
        }
        return is_synapse
    }

    //
    // Check and validate parameters
    //
    public static void sraInitialise(params, valid_params) {
        // Check minimal ENA fields are provided to download FastQ files
        def ena_metadata_fields = params.ena_metadata_fields ? params.ena_metadata_fields.split(',').collect{ it.trim().toLowerCase() } : valid_params['ena_metadata_fields']
        if (!ena_metadata_fields.containsAll(valid_params['ena_metadata_fields'])) {
            Nextflow.error("Invalid option: '${params.ena_metadata_fields}'. Minimally required fields for '--ena_metadata_fields': '${valid_params['ena_metadata_fields'].join(',')}'")
        }
    }

    //
    // Print a warning after pipeline has completed
    //
    public static void sraCurateSamplesheetWarn(log) {
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
    public static Map synapseShowToMap(synapse_file) {
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
    public static void synapseCurateSamplesheetWarn(log) {
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
    public static String synapseSampleNameFromFastQ(input_file, pattern) {

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
}
