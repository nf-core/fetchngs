
process CONSENSUS_ANCHORS {
    tag "$fastq_id"
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    tuple val(fastq_id), path(fastq), path(anchors_annot)
    val looklength

    output:
    tuple val(fastq_id), path(fastq), path(anchors_annot)    , emit: fastq_anchors
    path "*_consensus.fasta"                                            , emit: consensus_fasta
    path "*.tab"                                                        , emit: stats
    path "*.log"                                                        , emit: log

    script:
    """
    consensus_anchors.py \\
        --anchors_annot ${anchors_annot} \\
        --fastq_file ${fastq} \\
        --fastq_id ${fastq_id} \\
        --looklength ${looklength}
    """
}
