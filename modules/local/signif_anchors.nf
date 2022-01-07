
process SIGNIF_ANCHORS {
    tag "$fastq_id"
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    tuple val(fastq_id), path(fastq), path(anchors_annot)
    val direction
    val q_val

    output:
    path "*tsv"                                             , emit: tsv

    script:
    signif_anchors_file = "${fastq_id}_signif_anchors.tsv"
    """
    extract_signif_anchors.py \\
        --anchors_annot ${anchors_annot} \\
        --signif_anchors_file ${signif_anchors_file} \\
        --direction ${direction} \\
        --q_val ${q_val}
    """
}
