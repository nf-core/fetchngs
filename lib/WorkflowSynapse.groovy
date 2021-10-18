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

    //
    // Obtain Sample ID from File Name
    //
    public static String sampleNameFromFastQ(input_file, pattern) {

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
