
process SYNAPSE_GET {
    tag "$meta.id"
    label 'process_low'
    label 'error_retry'

    conda (params.enable_conda ? "bioconda::synapseclient=2.4.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/synapseclient:2.4.0--pyh5e36f6f_0' :
        'quay.io/biocontainers/synapseclient:2.4.0--pyh5e36f6f_0' }"

    input:
    val meta
    path config

    output:
    tuple val(meta), path("*.fastq.gz"), emit: fastq
    tuple val(meta), path("*md5")      , emit: md5
    path "versions.yml"                , emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    synapse \\
        -c $config \\
        get \\
        $args \\
        $meta.id

    echo "${meta.md5} \t ${meta.name}" > ${meta.id}.md5

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        synapse: \$(synapse --version | sed -e "s/Synapse Client //g")
    END_VERSIONS
    """
}
