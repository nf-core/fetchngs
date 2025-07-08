include { CUSTOM_SRATOOLSNCBISETTINGS } from '../../../modules/nf-core/custom/sratoolsncbisettings/main'
include { SRATOOLS_PREFETCH           } from '../../../modules/nf-core/sratools/prefetch/main'
include { SRATOOLS_FASTERQDUMP        } from '../../../modules/nf-core/sratools/fasterqdump/main'

//
// Download FASTQ sequencing reads from the NCBI's Sequence Read Archive (SRA).
//
workflow FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS {
    take:
    sra_metadata    : Channel<SraMetadata>
    dbgap_key       : Path?

    main:
    //
    // Detect existing NCBI user settings or create new ones.
    //
    ncbi_settings = CUSTOM_SRATOOLSNCBISETTINGS( sra_metadata.collect() )

    //
    // Prefetch sequencing reads in SRA format.
    //
    sra = sra_metadata.map(SRATOOLS_PREFETCH, ncbi_settings: ncbi_settings, certificate: dbgap_key)

    //
    // Convert the SRA format into one or more compressed FASTQ files.
    //
    samples = sra_metadata
        .join(sra, 'id')
        .map(SRATOOLS_FASTERQDUMP, ncbi_settings: ncbi_settings, certificate: dbgap_key)

    emit:
    samples
}

record SraMetadata {
    id: String
    single_end: Boolean
}
