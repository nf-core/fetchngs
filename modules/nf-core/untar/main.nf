include { Sample } from '../../types/types'

process UNTAR {
    tag "$archive"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    Sample input
    String args = ''
    String args2 = ''
    String prefix = ''

    output:
    Sample untar = new Sample(meta, path("$prefix"))

    topic:
    [ task.process, 'untar', eval("echo \$(tar --version 2>&1) | sed 's/^.*(GNU tar) //; s/ Copyright.*\$//'") ] >> 'versions'

    script:
    meta = input.meta
    archive = input.files.first()
    if( !prefix )
        prefix = meta.id ? "${meta.id}" : archive.baseName.toString().replaceFirst(/\.tar$/, "")
    """
    mkdir $prefix

    ## Ensures --strip-components only applied when top level of tar contents is a directory
    ## If just files or multiple directories, place all in prefix
    if [[ \$(tar -taf ${archive} | grep -o -P "^.*?\\/" | uniq | wc -l) -eq 1 ]]; then
        tar \\
            -C $prefix --strip-components 1 \\
            -xavf \\
            $args \\
            $archive \\
            $args2
    else
        tar \\
            -C $prefix \\
            -xavf \\
            $args \\
            $archive \\
            $args2
    fi
    """

    stub:
    if( !prefix )
        prefix = meta.id ? "${meta.id}" : archive.baseName.toString().replaceFirst(/\.tar$/, "")
    """
    mkdir $prefix
    touch ${prefix}/file.txt
    """
}
