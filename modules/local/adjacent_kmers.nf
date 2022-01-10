
process ADJACENT_KMERS {
    tag "$fastq_id"
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    path adj_kmers
    val num_input_lines
    val kmer_size
    each fastq_tuple

    output:
    path "*.tsv"    , emit: tsv
    path "*.fasta"  , emit: fasta

    script:
    fastq_id = fastq_tuple[0]
    fastq = fastq_tuple[1]

    out_signif_anchors_fasta = "${fastq_id}_signif_anchors.fasta"
    out_adj_kmer_counts_file = "${fastq_id}_adj_kmers_counts.tsv"
    """
    count_adjacent_kmers.py \\
        --num_input_lines ${num_input_lines} \\
        --adj_kmers_file ${adj_kmers} \\
        --fastq_file ${fastq} \\
        --fastq_id ${fastq_id} \\
        --out_signif_anchors_fasta ${out_signif_anchors_fasta} \\
        --out_adj_kmer_counts_file ${out_adj_kmer_counts_file} \\
        --kmer_size ${kmer_size}
    """
}
