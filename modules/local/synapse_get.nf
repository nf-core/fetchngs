// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SYNAPSE_GET {
    tag "$meta.id"
    label 'process_low'
    label 'error_retry'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::synapseclient=2.4.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/synapseclient:2.4.0--pyh5e36f6f_0"
    } else {
        container "quay.io/biocontainers/synapseclient:2.4.0--pyh5e36f6f_0"
    }

    input:
    val meta
    path config

    output:
    tuple val(meta), path("*.fastq.gz"), emit: fastq
    tuple val(meta), path("*md5")      , emit: md5
    path "versions.yml"                , emit: versions

    script:
    """
    synapse \\
        -c $config \\
        get \\
        $options.args \\
        $meta.id

    find ./ -type f -name "*.fastq.gz" -exec echo "${meta.md5} " {} \\; > ${meta.id}.md5
    md5sum -c ${meta.id}.md5

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        ${getSoftwareName(task.process)}: \$(synapse --version | sed -e "s/Synapse Client //g")
    END_VERSIONS
    """
}
