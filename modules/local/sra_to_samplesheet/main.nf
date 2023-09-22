
process SRA_TO_SAMPLESHEET {
    tag "$meta.id"

    executor 'local'
    memory 100.MB

    input:
    val meta
    val pipeline
    val strandedness
    val mapping_fields

    output:
    tuple val(meta), path("*samplesheet.csv"), emit: samplesheet
    tuple val(meta), path("*mappings.csv")   , emit: mappings

    exec:
    //
    // Create samplesheet containing metadata
    //

    //  Remove custom keys needed to download the data
    def meta_clone = meta.clone()
    meta_clone.remove("id")
    meta_clone.remove("fastq_1")
    meta_clone.remove("fastq_2")
    meta_clone.remove("md5_1")
    meta_clone.remove("md5_2")
    meta_clone.remove("single_end")

    // Add relevant fields to the beginning of the map
    pipeline_map = [
        sample  : "${meta.id.split('_')[0..-2].join('_')}",
        fastq_1 : meta.fastq_1,
        fastq_2 : meta.fastq_2
    ]

    // Add nf-core pipeline specific entries
    if (pipeline) {
        if (pipeline == 'rnaseq') {
            pipeline_map << [ strandedness: strandedness ]
        } else if (pipeline == 'atacseq') {
            pipeline_map << [ replicate: 1 ]
        } else if (pipeline == 'taxprofiler') {
            pipeline_map << [ fasta: '' ]
        }
    }
    pipeline_map << meta_clone

    // Create a samplesheet
    samplesheet  = pipeline_map.keySet().collect{ '"' + it + '"'}.join(",") + '\n'
    samplesheet += pipeline_map.values().collect{ '"' + it + '"'}.join(",")

    // Write samplesheet to file
    def samplesheet_file = task.workDir.resolve("${meta.id}.samplesheet.csv")
    samplesheet_file.text = samplesheet

    //
    // Create sample id mappings file
    //
    mappings_map = pipeline_map.clone()
    def fields = mapping_fields ? ['sample'] + mapping_fields.split(',').collect{ it.trim().toLowerCase() } : []
    if ((mappings_map.keySet() + fields).unique().size() != mappings_map.keySet().size()) {
        error("Invalid option for '--sample_mapping_fields': ${mapping_fields}.\nValid options: ${mappings_map.keySet().join(', ')}")
    }

    // Create mappings
    mappings  = fields.collect{ '"' + it + '"'}.join(",") + '\n'
    mappings += mappings_map.subMap(fields).values().collect{ '"' + it + '"'}.join(",")

    // Write mappings to file
    def mappings_file = task.workDir.resolve("${meta.id}.mappings.csv")
    mappings_file.text = mappings
}
