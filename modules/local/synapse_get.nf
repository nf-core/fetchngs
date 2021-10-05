// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SYNAPSE_GET {
    tag '$synid'
    label 'process_high'
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
    path synapseconfig          // path to synapse.Config file

    output:
    path "*.fastq*"               , emit: fastq
    path "*.version.txt"          , emit: version

    script:
    def software = getSoftwareName(task.process)
    
    """
    synapse -c $synapseconfig get $synid 
    echo \$(synapse --version) > ${software}.version.txt
    """
}