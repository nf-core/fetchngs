
process PYSRADB {
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.7 bioconda::pysradb" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    val srp

    output:
    path outputFile, emit: ids

    script:
    outputFile = "ids_${srp}.txt"
    """
    pysradb srp-to-srr ${srp} | awk '(NR>1) {print \$2}' > ${outputFile}
    """
}
