
process PARSE_ANCHORS {
    tag "$fastq_id"
    label 'process_medium'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    path signif_anchors_file
    val num_input_lines
    val looklength
    val kmer_size
    val direction
    tuple val(fastq_id), path(fastq), path(anchors_annot)

    output:
    path "*_adj_kmers.tsv"      , emit: tsv
    path "*_consensus.fasta"    , emit: consensus_fasta
    path "*.tab"                , emit: stats
    path "*.log"                , emit: log

    script:
    out_consensus_fasta_file    = "${fastq_id}_consensus.fasta"
    out_counts_file             = "${fastq_id}_counts.tab"
    out_fractions_file          = "${fastq_id}_fractions.tab"
    out_adj_kmer_file           = "${fastq_id}_adj_kmers.tsv"
    out_signif_anchors_fasta    = "${fastq_id}_signif_anchors.fasta"

    """
    parse_anchors.py \\
        --num_input_lines ${num_input_lines} \\
        --signif_anchors_file ${signif_anchors_file} \\
        --anchors_annot ${anchors_annot} \\
        --fastq_file ${fastq} \\
        --fastq_id ${fastq_id} \\
        --out_consensus_fasta_file ${out_consensus_fasta_file} \\
        --out_counts_file ${out_counts_file} \\
        --out_fractions_file ${out_fractions_file} \\
        --out_adj_kmer_file ${out_adj_kmer_file} \\
        --out_signif_anchors_fasta ${out_signif_anchors_fasta} \\
        --looklength ${looklength} \\
        --kmer_size ${kmer_size} \\
        --direction ${direction}
    """
}
