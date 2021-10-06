// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SYNAPSE_SHOW {
    tag "$synid"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::synapseclient=2.2.2" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE" // TODO: Add Singularity
    } else {
        container "sagebionetworks/synapsepythonclient:v2.4.0"
    }

    input:
    val synid                   // synapse ID for individual FastQ files

    output:
    path "*.metadata.txt", emit: metadata

    script:
    def software = getSoftwareName(task.process)

    """
    synapse show $synid | sed -n '1,3p;15,16p;20p;23p' > ${synid}.metadata.txt
    """
}
