workflow SAMPLESHEET_WRITER {
    take:
    ch_rows // channel: [ val(data_type), row ] ordered map starting with sample, fastq_1, fastq_2
    mapping_fields // val: comma-separated columns for <data_type>/samplesheet/id_mappings.csv
    outdir // val: output directory

    main:
    // Collect the rows of each data type in samplesheet_<data_type>.csv, then write it to <outdir>/<data_type>/samplesheet/
    ch_samplesheet = ch_rows
        .collectFile(newLine: true, keepHeader: true, sort: true) { entry ->
            def (data_type, row) = entry
            return ["samplesheet_${data_type}.csv", toCsvRecord(row.keySet() as List, row)]
        }
        .map { tmp -> writeToDataTypeDir(tmp, 'samplesheet', outdir) }

    ch_mappings = ch_rows
        .collectFile(newLine: true, keepHeader: true, sort: true) { entry ->
            def (data_type, row) = entry
            def fields = mapping_fields ? ['sample'] + mapping_fields.split(',').collect { field -> field.trim().toLowerCase() } : []
            if ((row.keySet() + fields).unique().size() != row.keySet().size()) {
                error("Invalid option for '--sample_mapping_fields': ${mapping_fields}.\nValid options: ${row.keySet().join(', ')}")
            }
            return ["id_mappings_${data_type}.csv", toCsvRecord(fields, row)]
        }
        .map { tmp -> writeToDataTypeDir(tmp, 'id_mappings', outdir) }

    emit:
    samplesheet = ch_samplesheet // channel: path(<data_type>/samplesheet/samplesheet.csv)
    mappings    = ch_mappings // channel: path(<data_type>/samplesheet/id_mappings.csv)
}

// FUNCTIONS

def toCsvRecord(fields, row) {
    def header = fields.collect { field -> '"' + field + '"' }.join(",")
    def values = fields.collect { field -> '"' + row[field] + '"' }.join(",")
    return "${header}\n${values}"
}

// Write a collected <name>_<data_type>.csv to <outdir>/<data_type>/samplesheet/<name>.csv without the trailing newline
def writeToDataTypeDir(tmp, name, outdir) {
    def data_type = tmp.baseName - "${name}_"
    def target = file("${outdir}/${data_type}/samplesheet/${name}.csv")
    target.parent.mkdirs()
    target.text = tmp.text.tokenize('\n').join('\n')
    return target
}
