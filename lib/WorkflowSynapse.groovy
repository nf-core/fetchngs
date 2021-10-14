//
// This file holds several functions specific to the workflow/synapse.nf in the nf-core/fetchngs pipeline
//

class WorkflowSynapse {

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
        meta.md5 = meta['File|md5']
        return meta.findAll{ it.value != null }
    }

    //
    // Print a warning after pipeline has completed
    //
    public static void curateSamplesheetWarn(log) {
        log.warn "=============================================================================\n" +
            "  Please double-check the samplesheet that has been auto-created by the pipeline.\n\n" +
            "  Where applicable, default values will be used for sample-specific metadata\n" +
            "  such as strandedness, controls etc as this information is not provided\n" +
            "  in a standardised manner when uploading data to Synapse.\n" +
            "==================================================================================="
    }
}
