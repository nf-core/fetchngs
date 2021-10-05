// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SYNAPSE_METADATA_MAPPING {
    tag "${data[3]}"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    input: 
    val data

    output:
    path("*metasheet.csv"), emit: metasheet

    exec:
    meta_map = [
        md5         : "${data[0]}",
        fileSize    : "${data[1]}",
        etag        : "${data[2]}",
        id          : "${data[3]}",
        fileName    : "${data[4]}",
        fileVersion : "${data[5]}"
    ]

    // Create Metadata Sheet
    metasheet  = meta_map.keySet().collect{ '"' + it + '"'}.join(",") + '\n'
    metasheet += meta_map.values().collect{ '"' + it + '"'}.join(",")

    def metasheet_file = task.workDir.resolve("${meta_map.id}.metasheet.csv")
    metasheet_file.text = metasheet
}
