
process DGMFINDER_ANALYSIS {
    tag "$fastq_id"
    label 'process_long'

    conda (params.enable_conda ? "conda-forge::python=3.9.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    path fastq
    path ann_file
    val kmer_size
    val max_dgmfinder_reads

    output:
    tuple val(fastq_id), path(fastq), path("*_anchors_annot.txt.gz")    , emit: fastq_anchors
    path "*_targets.txt.gz"                                             , emit: targets
    path "*_anchors.txt.gz"                                             , emit: anchors
    path "*_assemb_anchors.fasta"                                       , emit: assemb_anchors
    path "*_max_anchor_up.fasta"                                        , emit: max_anchor_up
    path "*_max_anchor_dn.fasta"                                        , emit: max_anchor_dn
    path "*.xml"                                                        , emit: xml
    path "*.log"                                                        , emit: log

    script:
    fastq_id = fastq.simpleName
    """
    dgmfinder.py \\
        --fastq_id ${fastq_id} \\
        --fastq_file ${fastq} \\
        --ann_file ${ann_file} \\
        --kmer_size ${kmer_size} \\
        --max_dgmfinder_reads ${max_dgmfinder_reads}
    """
}
