
process SRA_IDS_TO_RUNINFO {
    tag "$id"
    label 'error_retry'

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
    String id
    String fields

    output:
    Path tsv = path("*.runinfo.tsv")

    topic:
    [ task.process, 'python', eval("python --version | sed 's/Python //g'") ] >> 'versions'

    script:
    def metadata_fields = fields ? "--ena_metadata_fields ${fields}" : ''
    """
    echo $id > id.txt
    sra_ids_to_runinfo.py \\
        id.txt \\
        ${id}.runinfo.tsv \\
        $metadata_fields
    """
}
