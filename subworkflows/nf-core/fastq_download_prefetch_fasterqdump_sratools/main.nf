include { CUSTOM_SRATOOLSNCBISETTINGS } from '../../../modules/nf-core/custom/sratoolsncbisettings/main'
include { SRATOOLS_PREFETCH           } from '../../../modules/nf-core/sratools/prefetch/main'
include { SRATOOLS_FASTERQDUMP        } from '../../../modules/nf-core/sratools/fasterqdump/main'

//
// Download FASTQ sequencing reads from the NCBI's Sequence Read Archive (SRA).
//
workflow FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS {
    take:
    ch_sra_ids  // channel: [ val(meta), val(id) ]

    main:

    ch_versions = Channel.empty()

    //
    // Detect existing NCBI user settings or create new ones.
    //
    CUSTOM_SRATOOLSNCBISETTINGS()
    def settings = CUSTOM_SRATOOLSNCBISETTINGS.out.ncbi_settings  // value channel: path(settings)
    ch_versions = ch_versions.mix(CUSTOM_SRATOOLSNCBISETTINGS.out.versions)

    //
    // Prefetch sequencing reads in SRA format and convert into one or more compressed FASTQ files.
    // If specified in params, use the provided JWT file for pulling protected SRA runs, else provide 
    // an empty list.
    //
    
    if (!params.dbgap_key) {
        
        SRATOOLS_PREFETCH ( ch_sra_ids, settings, [] ) 
        SRATOOLS_FASTERQDUMP ( SRATOOLS_PREFETCH.out.sra, settings, [] )

    } else {
        
        certificate = file(params.dbgap_key, checkIfExists: true) // optional input channel for JWT

        SRATOOLS_PREFETCH ( ch_sra_ids, settings, certificate ) 
        SRATOOLS_FASTERQDUMP ( SRATOOLS_PREFETCH.out.sra, settings, certificate ) 

    }

    ch_versions = ch_versions.mix(SRATOOLS_PREFETCH.out.versions.first())
    ch_versions = ch_versions.mix(SRATOOLS_FASTERQDUMP.out.versions.first())

    emit:
    reads    = SRATOOLS_FASTERQDUMP.out.reads  // channel: [ val(meta), [ reads ] ]
    versions = ch_versions                     // channel: [ versions.yml ]
}
