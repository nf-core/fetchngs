process FFQ {
    tag "$id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::ffq=0.2.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ffq:0.2.1--pyhdfd78af_0':
        'quay.io/biocontainers/ffq:0.2.1--pyhdfd78af_0' }"

    input:
    val id

    output:
    path "*.json"      , emit: json
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "$id"   
    """
    ffq \\
        $id \\
        $args \\
        > ${prefix}.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ffq: \$(echo \$(ffq --help 2>&1) | sed 's/^.*ffq //; s/: A command.*\$//' )
    END_VERSIONS
    """
}
