process PRIDEPY_STREAMFILESMETADATA {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pridepy:0.0.16--pyhdfd78af_0'
        : 'quay.io/biocontainers/pridepy:0.0.16--pyhdfd78af_0'}"

    input:
    tuple val(meta), val(pride_id)

    output:
    tuple val(meta), path("${prefix}.files.json"), emit: json
    tuple val("${task.process}"), val('pridepy'), eval('python -c "from importlib.metadata import version; print(version(\'pridepy\'))"'), emit: versions_pridepy, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    pridepy stream-files-metadata \\
        -a "${pride_id}" \\
        -o "${prefix}.files.json" \\
        ${args}

    # pridepy exits 0 even when the request fails, so fail explicitly on an empty file
    [ -s "${prefix}.files.json" ] || { echo "ERROR: No file metadata returned for ${pride_id}" >&2; exit 1; }
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo '[]' > ${prefix}.files.json
    """
}
