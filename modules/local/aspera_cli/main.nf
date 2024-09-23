process ASPERA_CLI {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/aspera-cli:4.14.0--hdfd78af_1' :
        'biocontainers/aspera-cli:4.14.0--hdfd78af_1' }"

    input:
    tuple val(meta), val(fastq)
    val user
    val args

    output:
    tuple val(meta), path("*fastq.gz"), emit: fastq
    tuple val(meta), path("*md5")     , emit: md5
    tuple val("${task.process}"), val('aspera_cli'), eval('ascli --version'), topic: versions

    script:
    def conda_prefix = ['singularity', 'apptainer'].contains(workflow.containerEngine) ? "export CONDA_PREFIX=/usr/local" : ""
    if (meta.single_end) {
        """
        $conda_prefix

        ascp \\
            $args \\
            -i \$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem \\
            ${user}@${fastq[0]} \\
            ${meta.id}.fastq.gz

        echo "${meta.md5_1}  ${meta.id}.fastq.gz" > ${meta.id}.fastq.gz.md5
        md5sum -c ${meta.id}.fastq.gz.md5
        """
    } else {
        """
        $conda_prefix

        ascp \\
            $args \\
            -i \$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem \\
            ${user}@${fastq[0]} \\
            ${meta.id}_1.fastq.gz

        echo "${meta.md5_1}  ${meta.id}_1.fastq.gz" > ${meta.id}_1.fastq.gz.md5
        md5sum -c ${meta.id}_1.fastq.gz.md5

        ascp \\
            $args \\
            -i \$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem \\
            ${user}@${fastq[1]} \\
            ${meta.id}_2.fastq.gz

        echo "${meta.md5_2}  ${meta.id}_2.fastq.gz" > ${meta.id}_2.fastq.gz.md5
        md5sum -c ${meta.id}_2.fastq.gz.md5
        """
    }
}

workflow {
    def input = [
        [ id:'SRX9626017_SRR13191702', single_end:false, md5_1: '89c5be920021a035084d8aeb74f32df7', md5_2: '56271be38a80db78ef3bdfc5d9909b98' ],
        [
            'fasp.sra.ebi.ac.uk:/vol1/fastq/SRR131/002/SRR13191702/SRR13191702_1.fastq.gz',
            'fasp.sra.ebi.ac.uk:/vol1/fastq/SRR131/002/SRR13191702/SRR13191702_2.fastq.gz'
        ]
    ]
    def user = 'era-fasp'
    def args = ''

    ASPERA_CLI (
        input,
        user,
        args
    )
}
