process ASPERA_CLI {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::aspera-cli=4.20.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/aspera-cli:4.20.0--hdfd78af_0' :
        'biocontainers/aspera-cli:4.20.0--hdfd78af_0' }"

    input:
    tuple val(meta), val(fastq)
    val user

    output:
    tuple val(meta), path("*fastq.gz"), emit: fastq
    tuple val(meta), path("*md5")     , emit: md5
    tuple val("${task.process}"), val('aspera_cli'), eval('gem list aspera-cli | grep -o "[0-9][0-9.]*"'), emit: versions_aspera_cli, topic: versions

    script:
    def args = task.ext.args ?: ''
    if (meta.single_end) {
        """
        if [ ! -w "\${HOME:-/}" ]; then
            export HOME=\$(mktemp -d)
        fi
        if [ ! -d "\${HOME}/.aspera/sdk" ]; then
            ascli conf ascp install 1>&2
        fi
        ASCP=\$(find "\${HOME}/.aspera/sdk" -name "ascp" -type f | head -1)
        BYPASS_KEY="${moduleDir}/assets/aspera_bypass_rsa.pem"

        "\$ASCP" \\
            $args \\
            -i "\$BYPASS_KEY" \\
            ${user}@${fastq[0]} \\
            ${meta.id}.fastq.gz

        echo "${meta.md5_1}  ${meta.id}.fastq.gz" > ${meta.id}.fastq.gz.md5
        md5sum -c ${meta.id}.fastq.gz.md5
        """
    } else {
        """
        if [ ! -w "\${HOME:-/}" ]; then
            export HOME=\$(mktemp -d)
        fi
        if [ ! -d "\${HOME}/.aspera/sdk" ]; then
            ascli conf ascp install 1>&2
        fi
        ASCP=\$(find "\${HOME}/.aspera/sdk" -name "ascp" -type f | head -1)
        BYPASS_KEY="${moduleDir}/assets/aspera_bypass_rsa.pem"

        "\$ASCP" \\
            $args \\
            -i "\$BYPASS_KEY" \\
            ${user}@${fastq[0]} \\
            ${meta.id}_1.fastq.gz

        echo "${meta.md5_1}  ${meta.id}_1.fastq.gz" > ${meta.id}_1.fastq.gz.md5
        md5sum -c ${meta.id}_1.fastq.gz.md5

        "\$ASCP" \\
            $args \\
            -i "\$BYPASS_KEY" \\
            ${user}@${fastq[1]} \\
            ${meta.id}_2.fastq.gz

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
    } else {
        """
        echo | gzip > ${meta.id}_1.fastq.gz
        echo | gzip > ${meta.id}_2.fastq.gz
        touch ${meta.id}_1.fastq.gz.md5
        touch ${meta.id}_2.fastq.gz.md5
        """
    }

}
