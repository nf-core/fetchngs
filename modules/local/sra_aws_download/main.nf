process SRA_AWS_DOWNLOAD {
    tag "$meta.id"
    label 'process_low'
    label 'error_retry'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/awscli:1.8.3--py35_0' :
        'quay.io/biocontainers/awscli:1.8.3--py35_0' }"

    input:
    tuple val(meta), val(run_accession)

    output:
    tuple val(meta), path("*.sra"), emit: sra
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${run_accession}"
    """
    # Download SRA file from AWS S3 Open Data Program
    aws s3 cp \\
        --region us-east-1 \\
        --no-sign-request \\
        ${args} \\
        s3://sra-pub-run-odp/sra/${run_accession}/${run_accession} \\
        ${prefix}.sra

    # Verify download
    if [ ! -f "${prefix}.sra" ]; then
        echo "ERROR: Failed to download ${run_accession} from AWS S3"
        exit 1
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aws-cli: \$(aws --version 2>&1 | sed 's/aws-cli\\///; s/ Python.*//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${run_accession}"
    """
    touch ${prefix}.sra

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aws-cli: \$(aws --version 2>&1 | sed 's/aws-cli\\///; s/ Python.*//')
    END_VERSIONS
    """
}