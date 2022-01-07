
process ADJACENT_KMERS {
    tag "$fastq_id"
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    path signif_anchors
    val direction
    val kmer_size
    val adj_dist
    val adj_len
    each fastq

    output:
    path "*.tsv"    , emit: tsv
    path "*.fasta"  , emit: fasta

    script:
    signif_anchors_reads_file = "${fastq_id}_signif_anchors.fasta"
    adjacent_anchors_file = "${fastq_id}_adjacent_anchors.tsv"
    """
    extract_adjacent_kmers.py \\
        --signif_anchors_file ${signif_anchors} \\
        --fastq_file ${fastq} \\
        --signif_anchors_reads_file ${signif_anchors_reads_file} \\
        --adjacent_anchors_file ${adjacent_anchors_file} \\
        --kmer_size ${kmer_size} \\
        --adj_dist ${adj_dist} \\
        --adj_len ${adj_len}
    """
}
