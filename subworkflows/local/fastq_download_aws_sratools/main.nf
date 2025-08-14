include { CUSTOM_SRATOOLSNCBISETTINGS } from '../../../modules/nf-core/custom/sratoolsncbisettings/main'
include { SRA_AWS_DOWNLOAD            } from '../../../modules/local/sra_aws_download/main'
include { SRATOOLS_FASTERQDUMP        } from '../../../modules/nf-core/sratools/fasterqdump/main'

//
// Download FASTQ sequencing reads from AWS S3 SRA mirror
//
workflow FASTQ_DOWNLOAD_AWS_SRATOOLS {
    take:
    ch_sra_ids   // channel: [ val(meta), val(id) ]
    ch_dbgap_key // channel: [ path(dbgap_key) ]

    main:

    ch_versions = Channel.empty()

    //
    // Detect existing NCBI user settings or create new ones.
    //
    CUSTOM_SRATOOLSNCBISETTINGS ( ch_sra_ids.collect() )
    ch_ncbi_settings = CUSTOM_SRATOOLSNCBISETTINGS.out.ncbi_settings
    ch_versions = ch_versions.mix(CUSTOM_SRATOOLSNCBISETTINGS.out.versions)

    //
    // Download SRA files from AWS S3
    //
    SRA_AWS_DOWNLOAD ( ch_sra_ids )
    ch_versions = ch_versions.mix(SRA_AWS_DOWNLOAD.out.versions.first())

    //
    // Convert the SRA format into one or more compressed FASTQ files.
    //
    SRATOOLS_FASTERQDUMP ( SRA_AWS_DOWNLOAD.out.sra, ch_ncbi_settings, ch_dbgap_key )
    ch_versions = ch_versions.mix(SRATOOLS_FASTERQDUMP.out.versions.first())

    emit:
    reads    = SRATOOLS_FASTERQDUMP.out.reads // channel: [ val(meta), [ reads ] ]
    versions = ch_versions                    // channel: [ versions.yml ]
}