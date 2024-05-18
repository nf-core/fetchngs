process SRATOOLS_FASTERQDUMP {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-5f89fe0cd045cb1d615630b9261a1d17943a9b6a:6a9ff0e76ec016c3d0d27e0c0d362339f2d787e6-0' :
        'quay.io/biocontainers/mulled-v2-5f89fe0cd045cb1d615630b9261a1d17943a9b6a:6a9ff0e76ec016c3d0d27e0c0d362339f2d787e6-0' }"

    input:
    Map meta
    Path sra
    Path ncbi_settings
    Path certificate
    String fasterqdump_args = '--split-files --include-technical'
    String pigz_args = ''
    String prefix = ''

    output:
    meta
    fastq = path('*.fastq.gz')

    topic:
    tuple( task.process, 'sratools', eval("fasterq-dump --version 2>&1 | grep -Eo '[0-9.]+'") ) >> 'versions'
    tuple( task.process, 'pigz',     eval("pigz --version 2>&1 | sed 's/pigz //g'") )           >> 'versions'

    script:
    if( !prefix )
        prefix = "${meta.id}"
    def outfile = meta.single_end ? "${prefix}.fastq" : prefix
    def key_file = ''
    if (certificate.toString().endsWith('.jwt')) {
        key_file += " --perm ${certificate}"
    } else if (certificate.toString().endsWith('.ngc')) {
        key_file += " --ngc ${certificate}"
    }
    """
    export NCBI_SETTINGS="\$PWD/${ncbi_settings}"

    fasterq-dump \\
        $fasterqdump_args \\
        --threads $task.cpus \\
        --outfile $outfile \\
        ${key_file} \\
        ${sra}

    pigz \\
        $pigz_args \\
        --no-name \\
        --processes $task.cpus \\
        *.fastq
    """
}
