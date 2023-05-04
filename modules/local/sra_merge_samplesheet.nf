process SRA_MERGE_SAMPLESHEET {

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

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
