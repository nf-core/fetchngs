process SRATOOLS_PREFETCH {
    tag "$id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sra-tools:3.0.8--h9f5acd7_0' :
        'biocontainers/sra-tools:3.0.8--h9f5acd7_0' }"

    input:
    Tuple2<Map,String> input
    Path ncbi_settings
    Path certificate
    String prefetch_args = ''
    String retry_args = '5 1 100'  // <num retries> <base delay in seconds> <max delay in seconds>

    output:
    Tuple2<Map,String> sra = input

    topic:
    [ task.process, 'sratools', eval("prefetch --version 2>&1 | grep -Eo '[0-9.]+'") ] >> 'versions'

    shell:
    meta = input.v1
    id = input.v2

    if (certificate) {
        if (certificate.toString().endsWith('.jwt')) {
            prefetch_args += " --perm ${certificate}"
        }
        else if (certificate.toString().endsWith('.ngc')) {
            prefetch_args += " --ngc ${certificate}"
        }
    }

    template 'retry_with_backoff.sh'
}
