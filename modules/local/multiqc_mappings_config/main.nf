
process MULTIQC_MAPPINGS_CONFIG {

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
    path csv

    output:
    path "*yml"        , emit: yml
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), topic: versions

    script:
    """
    multiqc_mappings_config.py \\
        $csv \\
        multiqc_config.yml
    """
}
