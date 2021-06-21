// Import generic module functions
include { saveFiles; getSoftwareName } from './functions'

params.options = [:]

process SRA_MERGE_SAMPLESHEET {
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "conda-forge::sed=4.7" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv1/biocontainers_v1.2.0_cv1.img"
    } else {
        container "biocontainers/biocontainers:v1.2.0_cv1"
    }

    input:
    path ('samplesheets/*')
    path ('mappings/*')

    output:
    path "*csv", emit: csv
    path "*tsv", emit: tsv

    script:
    """
    head -n 1 `ls ./samplesheets/* | head -n 1` > samplesheet.csv
    for fileid in `ls ./samplesheets/*`; do
        awk 'NR>1' \$fileid >> samplesheet.csv
    done

    head -n 1 `ls ./mappings/* | head -n 1` > mappings.tsv
    for fileid in `ls ./mappings/*`; do
        awk 'NR>1' \$fileid >> mappings.tsv
    done
    """
}
