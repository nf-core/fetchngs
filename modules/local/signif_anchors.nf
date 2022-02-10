
process SIGNIF_ANCHORS {
    tag "$fastq_id"
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::python=3.9.7 conda-forge::pandas conda-forge::numpy" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    tuple val(fastq_id), path(fastq), path(anchors_annot)
    val direction
    val q_val

    output:
    path "*tsv"         , emit: tsv
    path anchors_annot  , emit: anchors_annot

    script:
    signif_anchors_file = "${fastq_id}_signif_anchors.tsv"
    """
    signif_anchors.py \\
        --anchors_annot ${anchors_annot} \\
        --signif_anchors_file ${signif_anchors_file} \\
        --direction ${direction} \\
        --q_val ${q_val}
    """
}
