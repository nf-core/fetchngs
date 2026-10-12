include { WRITE_FILE } from '../../../modules/local/writefile'

workflow SAMPLESHEET_WRITER {
    take:
    ch_rows // channel: [ val(data_type), row ] ordered map starting with sample, fastq_1, fastq_2
    mapping_fields // val: comma-separated columns for id_mappings.csv

    main:
    // Build the samplesheet and id mappings lines of each data type and write all files with one WRITE_FILE call
    ch_files = ch_rows
        .groupTuple()
        .flatMap { data_type, rows ->
            def meta = [id: data_type]
            def fields = mapping_fields ? ['sample'] + mapping_fields.split(',').collect { field -> field.trim().toLowerCase() } : []
            rows.each { row ->
                if ((row.keySet() + fields).unique().size() != row.keySet().size()) {
                    error("Invalid option for '--sample_mapping_fields': ${mapping_fields}.\nValid options: ${row.keySet().join(', ')}")
                }
            }
            return [
                [meta, 'samplesheet.csv', toCsvLines(rows.first().keySet() as List, rows)],
                [meta, 'id_mappings.csv', toCsvLines(fields, rows)],
            ]
        }

    WRITE_FILE(ch_files)

    emit:
    samplesheet = WRITE_FILE.out.file.filter { _meta, file -> file.name == 'samplesheet.csv' } // channel: [ val(meta), path(samplesheet.csv) ]
    mappings    = WRITE_FILE.out.file.filter { _meta, file -> file.name == 'id_mappings.csv' } // channel: [ val(meta), path(id_mappings.csv) ]
}

// FUNCTIONS

def toCsvLines(fields, rows) {
    def header = fields.collect { field -> '"' + field + '"' }.join(",")
    def values = rows.collect { row -> fields.collect { field -> '"' + row[field] + '"' }.join(",") }.sort()
    return ([header] + values).findAll { line -> line }
}
