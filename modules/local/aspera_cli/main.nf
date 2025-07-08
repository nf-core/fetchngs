process ASPERA_CLI {
    tag "$id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/aspera-cli:4.14.0--hdfd78af_1' :
        'biocontainers/aspera-cli:4.14.0--hdfd78af_1' }"

    input:
    id              : String
    single_end      : Boolean
    fastq_aspera    : String
    md5_1           : String
    md5_2           : String?
    user            : String

    output:
    id      : String = id
    fastq_1 : Path  = file('*_1.fastq.gz')
    fastq_2 : Path? = file('*_2.fastq.gz')
    md5_1   : Path  = file('*_1.fastq.gz.md5')
    md5_2   : Path? = file('*_2.fastq.gz.md5')

    topic:
    [process: task.process, name: 'aspera_cli', version: eval('ascli --version')] >> 'versions'

    script:
    def args = task.ext.args ?: ''
    def conda_prefix = ['singularity', 'apptainer'].contains(workflow.containerEngine) ? "export CONDA_PREFIX=/usr/local" : ""
    def fastq = fastq_aspera.tokenize(';')
    if (single_end) {
        """
        $conda_prefix

        ascp \\
            $args \\
            -i \$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem \\
            ${user}@${fastq[0]} \\
            ${id}.fastq.gz

        echo "${md5_1}  ${id}.fastq.gz" > ${id}.fastq.gz.md5
        md5sum -c ${id}.fastq.gz.md5
        """
    } else {
        """
        $conda_prefix

        ascp \\
            $args \\
            -i \$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem \\
            ${user}@${fastq[0]} \\
            ${id}_1.fastq.gz

        echo "${md5_1}  ${id}_1.fastq.gz" > ${id}_1.fastq.gz.md5
        md5sum -c ${id}_1.fastq.gz.md5

        ascp \\
            $args \\
            -i \$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem \\
            ${user}@${fastq[1]} \\
            ${id}_2.fastq.gz

        echo "${md5_2}  ${id}_2.fastq.gz" > ${id}_2.fastq.gz.md5
        md5sum -c ${id}_2.fastq.gz.md5
        """
    }
}
