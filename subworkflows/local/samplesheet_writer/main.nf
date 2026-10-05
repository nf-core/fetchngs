workflow SAMPLESHEET_WRITER {
    take:
    ch_rows // channel: [ row ] ordered map starting with sample, fastq_1, fastq_2
    pipeline // val: nf-core pipeline name
    strandedness // val: strandedness
    mapping_fields // val: comma-separated columns for id_mappings.csv
    outdir // val: output directory

    main:
    ch_pipeline_rows = ch_rows.map { row -> addPipelineColumns(row, pipeline, strandedness) }

    ch_samplesheet = ch_pipeline_rows
        .map { row -> toCsvRecord(row.keySet() as List, row) }
        .collectFile(name: 'tmp_samplesheet.csv', newLine: true, keepHeader: true, sort: true)
        .map { file -> file.text.tokenize('\n').join('\n') }
        .collectFile(name: 'samplesheet.csv', storeDir: "${outdir}/samplesheet")

    ch_mappings = ch_pipeline_rows
        .map { row ->
            def fields = mapping_fields ? ['sample'] + mapping_fields.split(',').collect { field -> field.trim().toLowerCase() } : []
            if ((row.keySet() + fields).unique().size() != row.keySet().size()) {
                error("Invalid option for '--sample_mapping_fields': ${mapping_fields}.\nValid options: ${row.keySet().join(', ')}")
            }
            return toCsvRecord(fields, row)
        }
        .collectFile(name: 'tmp_id_mappings.csv', newLine: true, keepHeader: true, sort: true)
        .map { file -> file.text.tokenize('\n').join('\n') }
        .collectFile(name: 'id_mappings.csv', storeDir: "${outdir}/samplesheet")

    emit:
    samplesheet = ch_samplesheet // channel: path(samplesheet.csv)
    mappings    = ch_mappings // channel: path(id_mappings.csv)
}

// FUNCTIONS

// Insert the extra columns required by downstream nf-core pipelines after fastq_2
def addPipelineColumns(row, pipeline, strandedness) {
    def pipeline_extras = [
        ampliseq: [run: ''],
        atacseq: [replicate: 1],
        mag: [group: '', short_reads_platform: 'ILLUMINA', long_reads_platform: ''],
        rnaseq: [strandedness: strandedness],
        sarek: [patient: row.sample_accession ?: row.sample],
        taxprofiler: [fasta: ''],
    ]
    def leading = ['sample', 'fastq_1', 'fastq_2']

    return row.subMap(leading) + (pipeline_extras[pipeline] ?: [:]) + row.subMap(row.keySet() - leading)
}

def toCsvRecord(fields, row) {
    def header = fields.collect { field -> '"' + field + '"' }.join(",")
    def values = fields.collect { field -> '"' + row[field] + '"' }.join(",")
    return "${header}\n${values}"
}
