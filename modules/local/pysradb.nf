
process PYSRADB {
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    val srp

    output:
    path "ids_*"  , emit: ids

    script:
    """
    pysradb srp-to-srr ${srp} | cut -f2 -d' ' | tail -n +2 > ids_${srp}.txt
    """
}
