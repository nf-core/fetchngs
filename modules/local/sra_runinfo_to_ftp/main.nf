process SRA_RUNINFO_TO_FTP {
    tag "${runinfo.toString().tokenize(".")[0]}"

    conda "${moduleDir}/environment.yml"

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/python:3.9--1'
        : 'biocontainers/python:3.9--1'}"

    input:
    path runinfo

    output:
    path "*.tsv", emit: tsv
    tuple val("${task.process}"), val('python'), eval('python --version | sed "s/Python //g"'), emit: versions_python, topic: versions

    script:
    """
    sra_runinfo_to_ftp.py \\
        ${runinfo.join(',')} \\
        ${runinfo.toString().tokenize(".")[0]}.runinfo_ftp.tsv
    """

    stub:
    """
    touch ${runinfo.toString().tokenize(".")[0]}.runinfo_ftp.tsv
    """
}
