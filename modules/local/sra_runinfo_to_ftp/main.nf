
process SRA_RUNINFO_TO_FTP {

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
    runinfo : Path

    output:
    file('*.runinfo_ftp.tsv')

    topic:
    [process: task.process, name: 'python', version: eval("python --version | sed 's/Python //g'")] >> 'versions'

    script:
    """
    sra_runinfo_to_ftp.py \\
        ${runinfo} \\
        ${runinfo.baseName.tokenize(".")[0]}.runinfo_ftp.tsv
    """
}
