
process SRA_RUNINFO_TO_FTP {

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
    Path runinfo

    output:
    Path tsv = path("*.runinfo_ftp.tsv")

    topic:
    tuple( task.process, 'python', eval("python --version | sed 's/Python //g'") ) >> 'versions'

    script:
    """
    sra_runinfo_to_ftp.py \\
        ${runinfo.join(',')} \\
        ${runinfo.toString().tokenize(".")[0]}.runinfo_ftp.tsv
    """
}
