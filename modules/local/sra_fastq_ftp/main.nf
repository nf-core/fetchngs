process SRA_FASTQ_FTP {
    tag "${meta.id}"
    label 'process_low'
    label 'error_retry'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/29/2938c24ccc7875ffddf253ead323193a509f0061884a05f43224bb25d9d85b12/data'
        : 'community.wave.seqera.io/library/gzip_wget:041a8ba200c3fa3f'}"

    input:
    tuple val(meta), val(fastq)

    output:
    tuple val(meta), path("*fastq.gz"), emit: fastq
    tuple val(meta), path("*md5"), emit: md5
    tuple val("${task.process}"), val('wget'), eval('wget --version | head -n 1 | sed  "s/^GNU Wget //; s/ .*\$//"'), emit: versions_wget, topic: versions

    script:
    def args = task.ext.args ?: ''
    if (meta.single_end) {
        """
        wget \\
            ${args} \\
            -O ${meta.id}.fastq.gz \\
            ${fastq[0]}

        echo "${meta.md5_1}  ${meta.id}.fastq.gz" > ${meta.id}.fastq.gz.md5
        md5sum -c ${meta.id}.fastq.gz.md5
        """
    }
    else {
        """
        wget \\
            ${args} \\
            -O ${meta.id}_1.fastq.gz \\
            ${fastq[0]}

        echo "${meta.md5_1}  ${meta.id}_1.fastq.gz" > ${meta.id}_1.fastq.gz.md5
        md5sum -c ${meta.id}_1.fastq.gz.md5

        wget \\
            ${args} \\
            -O ${meta.id}_2.fastq.gz \\
            ${fastq[1]}

        echo "${meta.md5_2}  ${meta.id}_2.fastq.gz" > ${meta.id}_2.fastq.gz.md5
        md5sum -c ${meta.id}_2.fastq.gz.md5
"""
    }

    stub:
    if (meta.single_end) {
        """
        echo | gzip > ${meta.id}.fastq.gz
        touch ${meta.id}.fastq.gz.md5
        """
    }
    else {
        """
        echo | gzip > ${meta.id}_1.fastq.gz
        echo | gzip > ${meta.id}_2.fastq.gz
        touch ${meta.id}_1.fastq.gz.md5
        touch ${meta.id}_2.fastq.gz.md5
        """
    }
}
