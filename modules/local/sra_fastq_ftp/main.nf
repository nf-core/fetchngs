
process SRA_FASTQ_FTP {
    tag "$id"
    label 'process_low'
    label 'error_retry'

    conda "conda-forge::wget=1.21.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/wget:1.21.4' :
        'biocontainers/wget:1.21.4' }"

    input:
    id              : String
    single_end      : Boolean
    fastq_1         : String
    fastq_2         : String?
    md5_1           : String
    md5_2           : String?

    output:
    id      : String = id
    fastq_1 : Path  = file('*_1.fastq.gz')
    fastq_2 : Path? = file('*_2.fastq.gz')
    md5_1   : Path  = file('*_1.fastq.gz.md5')
    md5_2   : Path? = file('*_2.fastq.gz.md5')

    topic:
    [process: task.process, name: 'wget', version: eval("echo \$(wget --version | head -n 1 | sed 's/^GNU Wget //; s/ .*\$//')")] >> 'versions'

    script:
    def args = task.ext.args ?: ''
    if (single_end) {
        """
        wget \\
            $args \\
            -O ${id}.fastq.gz \\
            ${fastq_1}

        echo "${md5_1}  ${id}.fastq.gz" > ${id}.fastq.gz.md5
        md5sum -c ${id}.fastq.gz.md5
        """
    } else {
        """
        wget \\
            $args \\
            -O ${id}_1.fastq.gz \\
            ${fastq_1}

        echo "${md5_1}  ${id}_1.fastq.gz" > ${id}_1.fastq.gz.md5
        md5sum -c ${id}_1.fastq.gz.md5

        wget \\
            $args \\
            -O ${id}_2.fastq.gz \\
            ${fastq_2}

        echo "${md5_2}  ${id}_2.fastq.gz" > ${id}_2.fastq.gz.md5
        md5sum -c ${id}_2.fastq.gz.md5
        """
    }
}
