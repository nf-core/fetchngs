process SAMPLESHEET_WRITE {
    tag "${meta.id}"

    input:
    tuple val(meta), val(rows)
    val mapping_fields

    output:
    tuple val(meta), path('samplesheet.csv'), emit: samplesheet
    tuple val(meta), path('id_mappings.csv'), emit: mappings

    exec:
    def fields = mapping_fields ? ['sample'] + mapping_fields.split(',').collect { field -> field.trim().toLowerCase() } : []
    rows.each { row ->
        if ((row.keySet() + fields).unique().size() != row.keySet().size()) {
            error("Invalid option for '--sample_mapping_fields': ${mapping_fields}.\nValid options: ${row.keySet().join(', ')}")
        }
    }
    task.workDir.resolve('samplesheet.csv').text = toCsv(rows.first().keySet() as List, rows)
    task.workDir.resolve('id_mappings.csv').text = toCsv(fields, rows)
}

// Header line and one sorted line per row, all values quoted
def toCsv(fields, rows) {
    def header = fields.collect { field -> '"' + field + '"' }.join(",")
    def values = rows.collect { row -> fields.collect { field -> '"' + row[field] + '"' }.join(",") }.sort()
    return ([header] + values).findAll { line -> line }.join('\n')
}
