include { SAMPLESHEET_WRITE } from '../../../modules/local/samplesheet_write'

workflow SAMPLESHEET_WRITER {
    take:
    ch_rows // channel: [ val(data_type), row ] ordered map starting with sample, fastq_1, fastq_2
    mapping_fields // val: comma-separated columns for id_mappings.csv

    main:
    // Group the rows of each data type and write one samplesheet and id mappings file per data type
    ch_rows_by_data_type = ch_rows
        .groupTuple()
        .map { data_type, rows -> [[id: data_type], rows] }

    SAMPLESHEET_WRITE(ch_rows_by_data_type, mapping_fields)

    emit:
    samplesheet = SAMPLESHEET_WRITE.out.samplesheet // channel: [ val(meta), path(samplesheet.csv) ]
    mappings    = SAMPLESHEET_WRITE.out.mappings // channel: [ val(meta), path(id_mappings.csv) ]
}
