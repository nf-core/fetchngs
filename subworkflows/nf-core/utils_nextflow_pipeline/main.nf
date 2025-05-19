//
// Subworkflow with functionality that may be useful for any Nextflow pipeline
//
include { fromYaml ; toJson } from 'plugin/nf-boost'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW DEFINITION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow UTILS_NEXTFLOW_PIPELINE {
    take:
    print_version        // boolean: print version
    dump_parameters      // boolean: dump parameters
    outdir               //    path: base directory used to publish pipeline results
    check_conda_channels // boolean: check conda channels

    main:

    //
    // Print workflow version and exit on --version
    //
    if (print_version) {
        log.info("${workflow.manifest.name} ${getWorkflowVersion()}")
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
    dummy_emit = true
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Generate version string
//
def getWorkflowVersion() {
    def version_string = "" as String
    if (workflow.manifest.version) {
        def prefix_v = workflow.manifest.version[0] != 'v' ? 'v' : ''
        version_string += "${prefix_v}${workflow.manifest.version}"
    }

    if (workflow.commitId) {
        def git_shortsha = workflow.commitId.substring(0, 7)
        version_string += "-g${git_shortsha}"
    }

    return version_string
}

//
// Dump pipeline parameters to a JSON file
//
def dumpParametersToJSON(outdir) {
    def timestamp = new java.util.Date().format('yyyy-MM-dd_HH-mm-ss')
    def params_file = file("${outdir}/pipeline_info/params_${timestamp}.json")
    params_file.text = toJson(params, true)
}

//
// When running with -profile conda, warn if channels have not been set-up appropriately
//
def checkCondaChannels() {
    def channels = []
    try {
        def config = fromYaml("conda config --show channels".execute().text)
        channels = config.channels
    }
    catch (NullPointerException e) {
        log.debug(e)
        log.warn("Could not verify conda channel configuration.")
        return null
    }
    catch (IOException e) {
        log.debug(e)
        log.warn("Could not verify conda channel configuration.")
        return null
    }

    // Check that all channels are present
    // This channel list is ordered by required channel priority.
    def required_channels_in_order = ['conda-forge', 'bioconda']
    def channels_missing = ((required_channels_in_order as Set) - (channels as Set)) as Boolean

    // Check that they are in the right order
    def channel_priority_violation = required_channels_in_order != channels.findAll { ch -> ch in required_channels_in_order }

    if (channels_missing | channel_priority_violation) {
        log.warn """\
        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            There is a problem with your Conda configuration!
            You will need to set-up the conda-forge and bioconda channels correctly.
            Please refer to https://bioconda.github.io/
            The observed channel order is
            ${channels}
            but the following channel order is required:
            ${required_channels_in_order}
        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        """.stripIndent(true)
    }
}
