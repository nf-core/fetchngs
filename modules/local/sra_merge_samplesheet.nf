
process SRA_MERGE_SAMPLESHEET {

    conda (params.enable_conda ? "conda-forge::sed=4.7" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv1/biocontainers_v1.2.0_cv1.img' :
        'biocontainers/biocontainers:v1.2.0_cv1' }"

    input:
    path ('samplesheets/*')
    path ('mappings/*')

    output:
    path "samplesheet.csv", emit: samplesheet
    path "id_mappings.csv", emit: mappings
    path "versions.yml"   , emit: versions

    script:
    """
    head -n 1 `ls ./samplesheets/* | head -n 1` > samplesheet.csv
    for fileid in `ls ./samplesheets/*`; do
        awk 'NR>1' \$fileid >> samplesheet.csv
    done

    head -n 1 `ls ./mappings/* | head -n 1` > id_mappings.csv
    for fileid in `ls ./mappings/*`; do
        awk 'NR>1' \$fileid >> id_mappings.csv
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """
}
