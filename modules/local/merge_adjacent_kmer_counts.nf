
process MERGE_ADJACENT_KMER_COUNTS {
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    path ch_adj_kmer_counts_samplesheet

    output:
    path "*.tsv", emit: tsv

    script:
    outfile = "anchor_adj_kmers_counts.tsv"
    """
    merge_adj_kmer_counts.py \\
        --samplesheet ${ch_adj_kmer_counts_samplesheet} \\
        --outfile ${outfile}
    """
}
