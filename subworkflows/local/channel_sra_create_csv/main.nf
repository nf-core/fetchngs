workflow CHANNEL_SRA_CREATE_CSV {
    take:
    ch_sra_metadata // channel: [ meta ]
    pipeline // val: pipeline name
    strandedness // val: strandedness
    mapping_fields // val: mapping fields
    outdir // val: output directory

    main:
    // Create samplesheet CSV from metadata
    ch_samplesheet = ch_sra_metadata
        .map { meta ->
            def pipeline_map = buildPipelineMap(meta, pipeline, strandedness)
            def header = pipeline_map.keySet().collect { key -> '"' + key + '"' }.join(",")
            def values = pipeline_map.values().collect { value -> '"' + value + '"' }.join(",")
            return "${header}\n${values}"
        }
        .collectFile(name: 'tmp_samplesheet.csv', newLine: true, keepHeader: true, sort: true)
        .map { file -> file.text.tokenize('\n').join('\n') }
        .collectFile(name: 'samplesheet.csv', storeDir: "${outdir}/samplesheet")

    // Create mappings CSV from selected fields
    ch_mappings = ch_sra_metadata
        .map { meta ->
            def pipeline_map = buildPipelineMap(meta, pipeline, strandedness)

            def fields = mapping_fields ? ['sample'] + mapping_fields.split(',').collect { field -> field.trim().toLowerCase() } : []
            if ((pipeline_map.keySet() + fields).unique().size() != pipeline_map.keySet().size()) {
                error("Invalid option for '--sample_mapping_fields': ${mapping_fields}.\nValid options: ${pipeline_map.keySet().join(', ')}")
            }

            def header = fields.collect { field -> '"' + field + '"' }.join(",")
            def values = fields.collect { field -> '"' + pipeline_map[field] + '"' }.join(",")
            return "${header}\n${values}"
        }
        .collectFile(name: 'tmp_id_mappings.csv', newLine: true, keepHeader: true, sort: true)
        .map { file -> file.text.tokenize('\n').join('\n') }
        .collectFile(name: 'id_mappings.csv', storeDir: "${outdir}/samplesheet")

    emit:
    samplesheet = ch_samplesheet
    mappings    = ch_mappings
}

// FUNTIONS

def buildPipelineMap(meta, pipeline, strandedness) {
    def m = meta instanceof List ? meta[0] : meta

    def meta_clone = m.clone()
    meta_clone.remove("id")
    meta_clone.remove("fastq_1")
    meta_clone.remove("fastq_2")
    meta_clone.remove("md5_1")
    meta_clone.remove("md5_2")
    meta_clone.remove("single_end")

    def pipeline_map = [sample: "${m.id.toString().split('_')[0..-2].join('_')}", fastq_1: m.fastq_1, fastq_2: m.fastq_2]

    if (pipeline) {
        if (pipeline == 'rnaseq') {
            pipeline_map << [strandedness: strandedness]
        }
        else if (pipeline == 'atacseq') {
            pipeline_map << [replicate: 1]
        }
        else if (pipeline == 'taxprofiler') {
            pipeline_map << [fasta: '']
        }
    }
    pipeline_map << meta_clone
    return pipeline_map
}
