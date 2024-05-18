
process SRA_RUNINFO_TO_FTP {

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
    runinfo : Path

    output:
    path("${prefix}.runinfo_ftp.tsv")

    topic:
    tuple( task.process, 'python', eval("python --version | sed 's/Python //g'") ) >> 'versions'

    script:
    prefix = runinfo.toString().tokenize(".")[0]
    """
    sra_runinfo_to_ftp.py \\
        ${runinfo.join(',')} \\
        ${prefix}.runinfo_ftp.tsv
    """
}
