// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SYNAPSE_MERGE_SAMPLESHEET {
    tag 'merge_samplesheet'
    label 'process_low'
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
    path ('metasheet/*')

    output:
    path "samplesheet.csv", emit: samplesheet
    path "metasheet.csv"  , emit: metasheet
    path "versions.yml"   , emit: versions

    script:
    """
    head -n 1 `ls ./samplesheets/* | head -n 1` > samplesheet.csv
    for fileid in `ls ./samplesheets/*`; do
        awk 'NR>1' \$fileid >> samplesheet.csv
    done

    head -n 1 `ls ./metasheet/* | head -n 1` > metasheet.csv
    for fileid in `ls ./metasheet/*`; do
        awk 'NR>1' \$fileid >> metasheet.csv
    done

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """
}
