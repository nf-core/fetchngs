/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ASPERA_CLI                                   } from '../../../modules/local/aspera_cli'
include { SRA_FASTQ_FTP                                } from '../../../modules/local/sra_fastq_ftp'
include { SRA_IDS_TO_RUNINFO                           } from '../../../modules/local/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP                           } from '../../../modules/local/sra_runinfo_to_ftp'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQDL                                      } from '../../../modules/nf-core/fastqdl'
include { FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS } from '../../nf-core/fastq_download_prefetch_fasterqdump_sratools'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FETCH_SRA {
    take:
    ids // channel: [ ids ]
    outdir // val: output directory
    dbgap_key // path: dbGaP repository key, or []
    download_method // val: 'aspera', 'ftp', 'sratools' or 'fastq-dl'
    ena_metadata_fields // val: comma-separated ENA metadata fields
    skip_fastq_download // val: boolean

    main:

    //
    // MODULE: Get SRA run information for public database ids
    //
    SRA_IDS_TO_RUNINFO(ids, ena_metadata_fields)

    //
    // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
    //
    SRA_RUNINFO_TO_FTP(SRA_IDS_TO_RUNINFO.out.tsv)

    ch_metadata = SRA_RUNINFO_TO_FTP.out.tsv
        .filter { row -> row.size() > 0 }
        .splitCsv(header: true, sep: '\t')
        .map { meta -> meta + [single_end: meta.single_end.toBoolean()] }
        .unique()

    if (!skip_fastq_download) {

        ch_reads = ch_metadata.branch { meta ->
            def final_download_method = 'ftp'
            // meta.fastq_aspera is a metadata string with ENA fasp links supported by Aspera
            // For single-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/ERR116/006/ERR1160846/ERR1160846.fastq.gz'
            // For paired-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_1.fastq.gz;fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_2.fastq.gz'
            if (meta.fastq_aspera && download_method == 'aspera') {
                final_download_method = 'aspera'
            }
            if (download_method == 'fastq-dl') {
                final_download_method = 'fastq-dl'
            }
            if ((!meta.fastq_aspera && !meta.fastq_1) || download_method == 'sratools') {
                final_download_method = 'sratools'
            }
            aspera: final_download_method == 'aspera'
            return [meta, meta.fastq_aspera.tokenize(';').take(2)]
            fastqdl: final_download_method == 'fastq-dl'
            return [meta, meta.run_accession]
            ftp: final_download_method == 'ftp'
            return [meta, [meta.fastq_1, meta.fastq_2]]
            sratools: final_download_method == 'sratools'
            return [meta, meta.run_accession]
        }

        //
        // MODULE: If FTP link is provided in run information then download FastQ directly via FTP and validate with md5sums
        //
        SRA_FASTQ_FTP(ch_reads.ftp)

        //
        // SUBWORKFLOW: Download sequencing reads without FTP links using sra-tools.
        //
        FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS(ch_reads.sratools, dbgap_key)

        //
        // MODULE: If Aspera link is provided in run information then download FastQ directly via Aspera CLI and validate with md5sums
        //
        ASPERA_CLI(ch_reads.aspera, 'era-fasp')

        //
        // MODULE: Download FastQ files with fastq-dl
        //
        FASTQDL(ch_reads.fastqdl)

        // Isolate FASTQ channel which will be added to emit block
        ch_metadata = SRA_FASTQ_FTP.out.fastq
            .mix(FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS.out.reads)
            .mix(ASPERA_CLI.out.fastq)
            .mix(FASTQDL.out.fastq)
            .map { meta, fastq ->
                def reads = fastq instanceof List ? fastq.flatten() : [fastq]

                return meta + [fastq_1: reads[0] ? "${outdir}/fastq/${reads[0].getName()}" : '', fastq_2: reads[1] && !meta.single_end ? "${outdir}/fastq/${reads[1].getName()}" : '']
            }
    }

    ch_samplesheet_rows = ch_metadata.map { meta -> sraSamplesheetRow(meta) }

    emit:
    metadata         = ch_metadata // channel: [ meta ]
    samplesheet_rows = ch_samplesheet_rows // channel: [ row ] ordered map, one per run
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Samplesheet row for a run: sample, fastq_1, fastq_2, then the SRA metadata columns
def sraSamplesheetRow(meta) {
    return [
        sample: "${meta.id.toString().split('_')[0..-2].join('_')}",
        fastq_1: meta.fastq_1,
        fastq_2: meta.fastq_2,
    ] + meta.subMap(meta.keySet() - ['id', 'md5_1', 'md5_2', 'single_end', 'fastq_1', 'fastq_2'])
}
