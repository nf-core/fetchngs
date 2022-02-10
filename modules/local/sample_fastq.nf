
process SAMPLE_FASTQ {
    tag "$fastq_id"
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.7" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    tuple val(fastq_id), path(fastq), path(anchors_annot)
    val num_input_lines

    output:
    tuple val(fastq_id), path(sub_fastq), path(anchors_annot), emit: fastq_anchors


    script:
    n_lines = num_input_lines * 4
    sub_fastq="sub_${n_lines}_${fastq_id}.fastq.gz"
    """
    zcat ${fastq} | head -n ${n_lines} | gzip > ${sub_fastq}
    """
}
