/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SRA_IDS_TO_RUNINFO                           } from '../../../modules/local/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP                           } from '../../../modules/local/sra_runinfo_to_ftp'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FETCH_NGS {
    take:
    ids // channel: [ ids ]
    ena_metadata_fields // val: comma-separated ENA metadata fields

    main:

    //
    // MODULE: Get SRA run information for public database ids
    //
    SRA_IDS_TO_RUNINFO(ids, ena_metadata_fields)

    //
    // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
    //
    SRA_RUNINFO_TO_FTP(SRA_IDS_TO_RUNINFO.out.tsv)

    ch_sra_metadata = SRA_RUNINFO_TO_FTP.out.tsv
        .filter { row -> row.size() > 0 }
        .splitCsv(header: true, sep: '\t')
        .map { meta -> meta + [single_end: meta.single_end.toBoolean()] }
        .unique()

    emit:
    metadata = ch_sra_metadata // channel: [ val(meta) ] metadata of each run
}
