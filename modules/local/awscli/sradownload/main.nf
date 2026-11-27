process AWSCLI_SRADOWNLOAD {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/23/235b74ea1d6d271a699e7fb8e0acd179187c53a25d2d1d091d6768f5ef51fead/data'
        : 'community.wave.seqera.io/library/awscli:2.38.3--d60d8e8caa5c0b93'}"

    input:
    tuple val(meta), val(id)

    output:
    tuple val(meta), path("${id}", type: 'dir'), emit: sra
    tuple val("${task.process}"), val('awscli'), eval("aws --version 2>&1 | cut -d' ' -f1 | cut -d/ -f2"), emit: versions_awscli, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # The output layout matches sratools/prefetch, so the file can be passed to sratools/fasterqdump
    aws s3 cp \\
        --no-sign-request \\
        --region us-east-1 \\
        --only-show-errors \\
        ${args} \\
        s3://sra-pub-run-odp/sra/${id}/${id} \\
        ${id}/${id}.sra
    """

    stub:
    """
    mkdir ${id}
    touch ${id}/${id}.sra
    """
}
