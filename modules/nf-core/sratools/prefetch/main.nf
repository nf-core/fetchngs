process SRATOOLS_PREFETCH {
    tag "$id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sra-tools:3.1.0--h9f5acd7_0' :
        'biocontainers/sra-tools:3.1.0--h9f5acd7_0' }"

    input:
    id              : String
    ncbi_settings   : Path
    certificate     : Path?

    output:
    id  : String = id
    sra : Path = file(id)

    topic:
    [process: task.process, name: 'sratools', version: eval("prefetch --version 2>&1 | grep -Eo '[0-9.]+'")] >> 'versions'

    shell:
    args_prefetch = task.ext.args_prefetch ?: ''
    args_retry = task.ext.args_retry ?: '5 1 100'  // <num retries> <base delay in seconds> <max delay in seconds>
    if (certificate) {
        if (certificate.baseName.endsWith('.jwt')) {
            args_prefetch += " --perm ${certificate}"
        }
        else if (certificate.baseName.endsWith('.ngc')) {
            args_prefetch += " --ngc ${certificate}"
        }
    }

    template 'retry_with_backoff.sh'

    stub:
    """
    mkdir $id
    touch $id/${id}.sra

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sratools: \$(prefetch --version 2>&1 | grep -Eo '[0-9.]+')
        curl: \$(curl --version | head -n 1 | sed 's/^curl //; s/ .*\$//')
    END_VERSIONS
    """
}
