
process SYNAPSE_SHOW {
    tag "$id"
    label 'process_low'

    conda "bioconda::synapseclient=2.7.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/synapseclient:2.7.1--pyh7cba7a3_0' :
        'biocontainers/synapseclient:2.7.1--pyh7cba7a3_0' }"

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
