process SRATOOLS_FASTERQDUMP {
    tag "$id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-5f89fe0cd045cb1d615630b9261a1d17943a9b6a:6a9ff0e76ec016c3d0d27e0c0d362339f2d787e6-0' :
        'quay.io/biocontainers/mulled-v2-5f89fe0cd045cb1d615630b9261a1d17943a9b6a:6a9ff0e76ec016c3d0d27e0c0d362339f2d787e6-0' }"

    input:
    id              : String
    single_end      : Boolean
    sra             : Path
    ncbi_settings   : Path
    certificate     : Path?

    output:
    id      : String = id
    fastq_1 : Path = files('*.fastq.gz').toSorted()[0]
    fastq_2 : Path? = !single_end ? files('*.fastq.gz').toSorted()[1] : null

    topic:
    [process: task.process, name: 'sratools', version: eval("fasterq-dump --version 2>&1 | grep -Eo '[0-9.]+'")] >> 'versions'
    [process: task.process, name: 'pigz',     version: eval("pigz --version 2>&1 | sed 's/pigz //g'")]           >> 'versions'

    script:
    def args_fasterqdump = task.ext.args_fasterqdump ?: ''
    def args_pigz = task.ext.args_pigz ?: ''
    def prefix = task.ext.prefix ?: "${id}"
    def outfile = single_end ? "${prefix}.fastq" : prefix
    def key_file = ''
    if (certificate.baseName.endsWith('.jwt')) {
        key_file += " --perm ${certificate}"
    } else if (certificate.baseName.endsWith('.ngc')) {
        key_file += " --ngc ${certificate}"
    }
    """
    export NCBI_SETTINGS="\$PWD/${ncbi_settings}"

    fasterq-dump \\
        $args_fasterqdump \\
        --threads $task.cpus \\
        --outfile $outfile \\
        ${key_file} \\
        ${sra}

    pigz \\
        $args_pigz \\
        --no-name \\
        --processes $task.cpus \\
        *.fastq
    """
}
