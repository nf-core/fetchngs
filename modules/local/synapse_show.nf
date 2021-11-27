
process SYNAPSE_SHOW {
    tag "$id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::synapseclient=2.4.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/synapseclient:2.4.0--pyh5e36f6f_0' :
        'quay.io/biocontainers/synapseclient:2.4.0--pyh5e36f6f_0' }"

    input:
    val id
    path config

    output:
    path "*.txt"       , emit: metadata
    path "versions.yml", emit: versions

    script:
    def args  = task.ext.args  ?: ''
    def args2 = task.ext.args2 ?: ''
    """
    synapse \\
        -c $config \\
        show \\
        $args \\
        $id \\
        $args2 \\
        > ${id}.metadata.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        synapse: \$(synapse --version | sed -e "s/Synapse Client //g")
    END_VERSIONS
    """
}
