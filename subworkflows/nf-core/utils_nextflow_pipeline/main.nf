//
// Subworkflow with functionality that may be useful for any Nextflow pipeline
//

// import org.yaml.snakeyaml.Yaml
// import groovy.json.JsonOutput
// import nextflow.extension.FilesEx

/*
========================================================================================
    SUBWORKFLOW DEFINITION
========================================================================================
*/

workflow UTILS_NEXTFLOW_PIPELINE {

    take:
    print_version       : boolean // print version
    dump_parameters     : boolean // dump parameters
    outdir              : String  // base directory used to publish pipeline results
    check_conda_channels: boolean // check conda channels

    main:

    //
    // Print workflow version and exit on --version
    //
    if (print_version) {
        log.info "${workflow.manifest.name} ${getWorkflowVersion()}"
        System.exit(0)
    }

    //
    // Dump pipeline parameters to a JSON file
    //
    if (dump_parameters && outdir) {
        dumpParametersToJSON(outdir)
    }

    //
    // When running with Conda, warn if channels have not been set-up appropriately
    //
    if (check_conda_channels) {
        checkCondaChannels()
    }

    emit:
    true
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

//
// Generate version string
//
fn getWorkflowVersion() -> String {
    var version_string = ""
    if (workflow.manifest.version) {
        let prefix_v = workflow.manifest.version[0] != 'v' ? 'v' : ''
        version_string += "${prefix_v}${workflow.manifest.version}"
    }

    if (workflow.commitId) {
        let git_shortsha = workflow.commitId.substring(0, 7)
        version_string += "-g${git_shortsha}"
    }

    return version_string
}

//
// Dump pipeline parameters to a JSON file
//
fn dumpParametersToJSON(outdir: String) {
    let timestamp  = new java.util.Date().format( 'yyyy-MM-dd_HH-mm-ss')
    let filename   = "params_${timestamp}.json"
    let temp_pf    = new File(workflow.launchDir.toString(), ".${filename}")
    let jsonStr    = JsonOutput.toJson(params)
    temp_pf.text   = JsonOutput.prettyPrint(jsonStr)

    FilesEx.copyTo(temp_pf.toPath(), "${outdir}/pipeline_info/params_${timestamp}.json")
    temp_pf.delete()
}

//
// When running with -profile conda, warn if channels have not been set-up appropriately
//
fn checkCondaChannels() {
    let parser = new Yaml()
    var channels: Set = []
    try {
        let config = parser.load("conda config --show channels".execute().text)
        channels = config.channels
    } catch(NullPointerException | IOException e) {
        log.warn "Could not verify conda channel configuration."
        return
    }

    // Check that all channels are present
    // This channel list is ordered by required channel priority.
    let required_channels_in_order: Set = ['conda-forge', 'bioconda', 'defaults']
    let channels_missing = !(required_channels_in_order - channels).isEmpty()

    // Check that they are in the right order
    let channel_priority_violation = false
    let n = required_channels_in_order.size()
    // for (int i = 0; i < n - 1; i++) {
    //     channel_priority_violation |= !(channels.indexOf(required_channels_in_order[i]) < channels.indexOf(required_channels_in_order[i+1]))
    // }

    if (channels_missing | channel_priority_violation) {
        log.warn "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
            "  There is a problem with your Conda configuration!\n\n" +
            "  You will need to set-up the conda-forge and bioconda channels correctly.\n" +
            "  Please refer to https://bioconda.github.io/\n" +
            "  The observed channel order is \n" +
            "  ${channels}\n" +
            "  but the following channel order is required:\n" +
            "  ${required_channels_in_order}\n" +
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    }
}
