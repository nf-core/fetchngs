
process GET_READ_LENGTH {

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    tuple val(fastq_id), path(fastq), path(anchors_annot)

    output:
    env read_length, emit: read_length

    script:
    """
    zcat ${fastq} > tmp.fastq
    read_length=\$(head -n 1 tmp.fastq | awk '{print length}')
    """
}
