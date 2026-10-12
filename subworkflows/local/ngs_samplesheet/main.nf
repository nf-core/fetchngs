include { WRITE_FILE              } from '../../../modules/local/writefile'
include { getSampleMappingFields } from '../utils_nfcore_fetchngs_pipeline'
include { toCsvLines             } from '../utils_nfcore_fetchngs_pipeline'

workflow NGS_SAMPLESHEET {
    take:
    ch_metadata // channel: [ val(meta) ] metadata of each run from FETCH_NGS
    pipeline // val: nf-core pipeline the samplesheet is for
    strandedness // val: strandedness for nf-core/rnaseq
    mapping_fields // val: comma-separated columns for id_mappings.csv

    main:
    ch_files = ch_metadata
        .map { meta -> buildPipelineMap(meta, pipeline, strandedness) }
        .collect()
        .flatMap { rows ->
            def meta = [id: 'ngs']
            def columns = rows.first().keySet() as List
            def fields = getSampleMappingFields(mapping_fields, columns)
            return [
                [meta, 'samplesheet.csv', toCsvLines(columns, rows)],
                [meta, 'id_mappings.csv', toCsvLines(fields, rows)],
            ]
        }

    WRITE_FILE(ch_files)

    emit:
    samplesheet = WRITE_FILE.out.file.filter { _meta, file -> file.name == 'samplesheet.csv' } // channel: [ val(meta), path(samplesheet.csv) ]
    mappings    = WRITE_FILE.out.file.filter { _meta, file -> file.name == 'id_mappings.csv' } // channel: [ val(meta), path(id_mappings.csv) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def buildPipelineMap(meta, pipeline, strandedness) {
    def pipeline_extras = [
        ampliseq: [run: ''],
        atacseq: [replicate: 1],
        mag: [group: '', short_reads_platform: '', long_reads_platform: ''],
        rnaseq: [strandedness: strandedness],
        sarek: [patient: meta.sample_accession],
        taxprofiler: [fasta: ''],
    ]

    return [
        sample: "${meta.id.toString().split('_')[0..-2].join('_')}",
        fastq_1: meta.fastq_1,
        fastq_2: meta.fastq_2,
    ] + (pipeline_extras[pipeline] ?: [:]) + meta.subMap(meta.keySet() - ['id', 'md5_1', 'md5_2', 'single_end', 'fastq_1', 'fastq_2'])
}
