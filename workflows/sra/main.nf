/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SRA_FASTQ_FTP           } from '../../modules/local/sra_fastq_ftp'
include { SRA_IDS_TO_RUNINFO      } from '../../modules/local/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP      } from '../../modules/local/sra_runinfo_to_ftp'
include { ASPERA_CLI              } from '../../modules/local/aspera_cli'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS } from '../../subworkflows/nf-core/fastq_download_prefetch_fasterqdump_sratools'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SRA {

    take:
    ids     : Channel<String>
    params  : SraParams

    main:
    //
    // MODULE: Get SRA run information for public database ids
    //
    runinfo = ids.map(SRA_IDS_TO_RUNINFO, fields: params.ena_metadata_fields)

    //
    // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
    //
    runinfo_ftp = runinfo.map(SRA_RUNINFO_TO_FTP)

    sra_metadata = runinfo_ftp
        .flatMap { tsv -> tsv.splitCsv(header:true, sep:'\t').toUnique() }
        .map { meta -> meta }

    //
    // MODULE: If FTP link is provided in run information then download FastQ directly via FTP and validate with md5sums
    //
    ftp_samples = sra_metadata
        .filter { meta -> !params.skip_fastq_download && meta instanceof FtpMetadata }
        .map(SRA_FASTQ_FTP)

    //
    // SUBWORKFLOW: Download sequencing reads without FTP links using sra-tools.
    //
    sratools_metadata = sra_metadata
        .filter { meta -> !params.skip_fastq_download && meta instanceof SratoolsMetadata }

    sratools_samples = FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS (
        sratools_metadata,
        params.dbgap_key
    )

    //
    // MODULE: If Aspera link is provided in run information then download FastQ directly via Aspera CLI and validate with md5sums
    //
    aspera_samples = sra_metadata
        .filter { meta -> !params.skip_fastq_download && meta instanceof AsperaMetadata }
        .map(ASPERA_CLI, user: 'era-fasp')

    samples = ftp_samples
        .mix(sratools_samples)
        .mix(aspera_samples)

    emit:
    samples     : Channel<Sample>   = samples
    runinfo_ftp : Channel<Path>     = runinfo_ftp
}

/*
========================================================================================
    TYPES
========================================================================================
*/

record SraParams {
    ena_metadata_fields         : String
    skip_fastq_download         : boolean
    dbgap_key                   : Path?
}

// fastq_aspera is a metadata string with ENA fasp links supported by Aspera
    // For single-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/ERR116/006/ERR1160846/ERR1160846.fastq.gz'
    // For paired-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_1.fastq.gz;fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_2.fastq.gz'
record AsperaMetadata {
    id              : String
    single_end      : Boolean
    fastq_aspera    : String
    md5_1           : String
    md5_2           : String?
}

record FtpMetadata {
    id              : String
    single_end      : Boolean
    fastq_1         : String
    fastq_2         : String?
    md5_1           : String
    md5_2           : String?
}

record SratoolsMetadata {
    id              : String
    single_end      : Boolean
}

record Sample {
    id      : String
    fastq_1 : Path
    fastq_2 : Path?
    md5_1   : Path?
    md5_2   : Path?
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
