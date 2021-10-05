// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SYNAPSE_TO_SAMPLESHEET {
    tag '$id'
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    input:
    tuple val(id), val(files)
    val strandedness

    output:
    path("*samplesheet.csv"), emit: samplesheet

    exec:

    // Add fields to the beginning of the map
    pipeline_map = [
        sample  : "${id}",
        fastq_1 : "${params.outdir}/${params.results_dir}/${files[0].getBaseName()}",
        fastq_2 : "${params.outdir}/${params.results_dir}/${files[1].getBaseName()}"
    ]
    // Add Strandedness
    pipeline_map << [ strandedness: "${strandedness}" ]
    
    // Create Samplesheet
    samplesheet  = pipeline_map.keySet().collect{ '"' + it + '"'}.join(",") + '\n'
    samplesheet += pipeline_map.values().collect{ '"' + it + '"'}.join(",")

    def samplesheet_file2 = task.workDir.resolve("${pipeline_map.sample}.samplesheet.csv")
    samplesheet_file2.text = samplesheet

}
