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

// FUNCTIONS

def buildPipelineMap(meta, pipeline, strandedness) {
    def sample = "${meta.id.toString().split('_')[0..-2].join('_')}"
    def metadata = meta.subMap(meta.keySet() - ['id', 'md5_1', 'md5_2', 'single_end', 'fastq_1', 'fastq_2'])
    if (pipeline == 'mag') {
        return [sample: sample] + buildMagColumns(meta) + metadata
    }

    def pipeline_extras = [
        ampliseq: [run: ''],
        atacseq: [replicate: 1],
        rnaseq: [strandedness: strandedness],
        sarek: [patient: meta.sample_accession],
        taxprofiler: [fasta: ''],
    ]

    return [
        sample: sample,
        fastq_1: meta.fastq_1,
        fastq_2: meta.fastq_2,
    ] + (pipeline_extras[pipeline] ?: [:]) + metadata
}

// nf-core/mag reads short and long reads from different columns. Every row gets all of them,
// since the rows are merged under the header of the first one.
def buildMagColumns(meta) {
    def platform = meta.instrument_platform ?: ''
    def is_long = platform in ['OXFORD_NANOPORE', 'PACBIO_SMRT']
    return [
        run: meta.id.toString().split('_')[-1],
        group: meta.study_accession ?: '0',
        short_reads_1: is_long ? '' : meta.fastq_1,
        short_reads_2: is_long ? '' : meta.fastq_2,
        short_reads_platform: is_long ? '' : platform,
        long_reads: is_long ? meta.fastq_1 : '',
        // ENA's PACBIO_SMRT does not say whether the reads are HiFi or CLR, which mag needs
        long_reads_platform: platform == 'OXFORD_NANOPORE' ? platform : '',
    ]
}
