process WRITE_FILE {
    tag "${meta.id}:${name}"

    input:
    tuple val(meta), val(name), val(items)

    output:
    tuple val(meta), path(name), emit: file

    exec:
    task.workDir.resolve(name).text = items.join('\n')
}
