
process MERGE_SIGNIF_ANCHORS {
    label 'error_retry'
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::python=3.9.7 conda-forge::pandas" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    path signif_anchors_samplesheet
    val direction
    val q_val
    val num_anchors

    output:
    path "*.tsv", emit: tsv

    script:
    outfile         = "signif_anchors_${params.direction}_qval_${params.q_val}.tsv"
    """
    merge_signif_anchors.py \\
        --samplesheet ${signif_anchors_samplesheet} \\
        --outfile ${outfile} \\
        --num_anchors ${num_anchors}
    """
}
