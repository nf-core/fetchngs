
process DGMFINDER {
    tag "$fastq_id"
    label 'error_retry'

    // conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/python:3.9--1' :
    //     'quay.io/biocontainers/python:3.9--1' }"

    input:
    path fastq
    path ann_file
    val kmer_size

    output:
    path "*_anchors.txt.gz"         , emit: anchors
    path "*_assemb_anchors.fasta"   , emit: assemb_anchors
    path "*_max_anchor_up.fasta"    , emit: max_anchor_up
    path "*_max_anchor_dn.fasta"    , emit: max_anchor_dn
    path "*_anchors_annot.txt.gz"   , emit: anchors_annot
    path "versions.yml"             , emit: versions

    script:
    fastq_id = fastq.simpleName
    """
    dgmfinder.py \\
        --fastq_id ${fastq_id} \\
        --fastq_file ${fastq} \\
        --ann_file ${ann_file} \\
        --kmer_size ${kmer_size}
    """
}
