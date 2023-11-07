process SRA_MERGE_SAMPLESHEET {

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    path 'samplesheets.txt'
    path 'mappings.txt'

    output:
    path "samplesheet.csv", emit: samplesheet
    path "id_mappings.csv", emit: mappings
    path "versions.yml"   , emit: versions

    script:
    """
    head -n 1 `head -n 1 samplesheets.txt` > samplesheet.csv
    while read fileid; do
        awk 'NR>1' \$fileid >> samplesheet.csv
    done < samplesheets.txt

    head -n 1 `head -n 1 mappings.txt` > id_mappings.csv
    while read fileid; do
        awk 'NR>1' \$fileid >> id_mappings.csv
    done < mappings.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """
}
