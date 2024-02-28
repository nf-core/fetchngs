
process SRA_TO_SAMPLESHEET {
    executor 'local'
    memory 100.MB

    input:
    val samples
    val pipeline
    val strandedness
    val mapping_fields

    output:
    path("samplesheet.csv"), emit: samplesheet
    path("id_mappings.csv"), emit: mappings

    exec:
    //  Remove custom keys needed to download the data
    def records = samples.collect { meta ->
        def meta_clone = meta.clone()
        meta_clone.remove("id")
        meta_clone.remove("fastq_1")
        meta_clone.remove("fastq_2")
        meta_clone.remove("md5_1")
        meta_clone.remove("md5_2")
        meta_clone.remove("single_end")

        // Add relevant fields to the beginning of the map
        def record = [
            sample  : "${meta.id.split('_')[0..-2].join('_')}",
            fastq_1 : meta.fastq_1,
            fastq_2 : meta.fastq_2
        ]

        // Add nf-core pipeline specific entries
        if (pipeline) {
            if (pipeline == 'rnaseq') {
                record << [ strandedness: strandedness ]
            } else if (pipeline == 'atacseq') {
                record << [ replicate: 1 ]
            } else if (pipeline == 'taxprofiler') {
                record << [ fasta: '' ]
            }
        }
        record << meta_clone
    }

    //
    // Create samplesheet containing metadata
    //
    def samplesheet_lines = []
    samplesheet_lines << records.first().keySet().collect{ '"' + it + '"'}.join(",")
    records.each { record ->
        samplesheet_lines << record.values().collect{ '"' + it + '"'}.join(",")
    }

    def samplesheet_file = task.workDir.resolve("samplesheet.csv")
    samplesheet_file.text = samplesheet_lines.join('\n')

    //
    // Create sample id mappings file
    //
    def fields = mapping_fields ? ['sample'] + mapping_fields.split(',').collect{ it.trim().toLowerCase() } : []

    def mapping_lines = []
    mapping_lines << fields.collect{ '"' + it + '"'}.join(",")
    records.each { record ->
        def mappings_map = record.clone()
        if ((mappings_map.keySet() + fields).unique().size() != mappings_map.keySet().size()) {
            error("Invalid option for '--sample_mapping_fields': ${mapping_fields}.\nValid options: ${mappings_map.keySet().join(', ')}")
        }
        mapping_lines << mappings_map.subMap(fields).values().collect{ '"' + it + '"'}.join(",")
    }

    def mappings_file = task.workDir.resolve("id_mappings.csv")
    mappings_file.text = mapping_lines.join('\n')
}
