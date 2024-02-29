
/**
 * Save a list of records to a samplesheet file.
 *
 * @param records
 * @param path
 */
def toSamplesheet(List<Map> records, Path path) {
    def lines = []
    lines << records.first().keySet().collect{ '"' + it + '"'}.join(",")
    records.each { record ->
        lines << record.values().collect{ '"' + it + '"'}.join(",")
    }

    path.text = lines.join('\n')
}

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
        record
    }

    //
    // Create samplesheet containing metadata
    //
    def samplesheet_file = task.workDir.resolve("samplesheet.csv")
    toSamplesheet(records, samplesheet_file)

    //
    // Create sample id mappings file
    //
    def fields = mapping_fields ? ['sample'] + mapping_fields.split(',').collect{ it.trim().toLowerCase() } : []
    def mapping_records = records.collect { record ->
        if ((record.keySet() + fields).unique().size() != record.keySet().size()) {
            error("Invalid option for '--sample_mapping_fields': ${mapping_fields}.\nValid options: ${record.keySet().join(', ')}")
        }
        record.subMap(fields)
    }

    def mappings_file = task.workDir.resolve("id_mappings.csv")
    toSamplesheet(mapping_records, mappings_file)
}
