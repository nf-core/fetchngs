
process MERGE_SIGNIF_ANCHORS {
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    path signif_anchors_samplesheet
    val direction
    val q_val

    output:
    path "*.tsv", emit: tsv

    script:
    outfile = "signif_anchors_${params.direction}_qval_${params.q_val}.tsv"
    """
    merge_signif_anchors.py \\
        --samplesheet ${signif_anchors_samplesheet} \\
        --outfile ${outfile}
    """
}
