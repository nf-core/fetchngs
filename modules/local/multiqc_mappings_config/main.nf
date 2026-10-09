process MULTIQC_MAPPINGS_CONFIG {
    tag "${meta.id}"

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/python:3.9--1'
        : 'biocontainers/python:3.9--1'}"

    input:
    tuple val(meta), path(csv)

    output:
    tuple val(meta), path("*config.yml"), emit: yml
    tuple val("${task.process}"), val('python'), eval('python --version | sed "s/Python //g"'), emit: versions_python, topic: versions

    script:
    """
    multiqc_mappings_config.py \\
        ${csv} \\
        multiqc_config.yml
    """

    stub:
    """
    touch multiqc_config.yml
    """
}
