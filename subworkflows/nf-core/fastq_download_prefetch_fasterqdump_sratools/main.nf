include { CUSTOM_SRATOOLSNCBISETTINGS } from '../../../modules/nf-core/custom/sratoolsncbisettings/main'
include { SRATOOLS_PREFETCH           } from '../../../modules/nf-core/sratools/prefetch/main'
include { SRATOOLS_FASTERQDUMP        } from '../../../modules/nf-core/sratools/fasterqdump/main'

//
// Download FASTQ sequencing reads from the NCBI's Sequence Read Archive (SRA).
//
workflow FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS {
    take:
    sra_ids                     // Channel<Tuple2<Map,String>>
    dbgap_key                   // Path
    sratools_fasterqdump_args   // String
    sratools_pigz_args          // String

    main:
    //
    // Detect existing NCBI user settings or create new ones.
    //
    sra_ids                                                 // Channel<Tuple2<Map,String>>
        |> collect                                          // List<Tuple2<Map,String>>
        |> CUSTOM_SRATOOLSNCBISETTINGS                      // Path
        |> set { ncbi_settings }                            // Path

    sra_ids                                                 // Channel<Tuple2<Map,String>>
        |> map { input ->
            //
            // Prefetch sequencing reads in SRA format.
            //
            input = SRATOOLS_PREFETCH ( input, ncbi_settings, dbgap_key )

            //
            // Convert the SRA format into one or more compressed FASTQ files.
            //
            SRATOOLS_FASTERQDUMP (
                input,
                ncbi_settings,
                dbgap_key,
                sratools_fasterqdump_args,
                sratools_pigz_args )
        }                                                   // Channel<Sample>
        |> set { reads }                                    // Channel<Sample>

    emit:
    reads   // Channel<Sample>
}
