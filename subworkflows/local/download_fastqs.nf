include { PYSRADB                 } from '../../modules/local/pysradb'
include { SRA_IDS_TO_RUNINFO      } from '../../modules/local/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP      } from '../../modules/local/sra_runinfo_to_ftp'
include { SRA_FASTQ_FTP           } from '../../modules/local/sra_fastq_ftp'
include { SRA_TO_SAMPLESHEET      } from '../../modules/local/sra_to_samplesheet'
include { SRA_MERGE_SAMPLESHEET   } from '../../modules/local/sra_merge_samplesheet'
include { SRATOOLS_PREFETCH       } from '../../modules/local/sratools_prefetch'
include { SRATOOLS_FASTERQDUMP    } from '../../modules/local/sratools_fasterqdump'

include { SRA_FASTQ_SRATOOLS      } from '../../subworkflows/local/sra_fastq_sratools'


workflow DOWNLOAD_FASTQS {
    take:

    main:

    // Read in inputs to ch_ids
    if (params.srp) {
        //
        // MODULE: Get SRR numbers from SRP project
        //
        PYSRADB (
            params.srp
        )

        // Read in ids from SRR numbers
        PYSRADB.out.ids
            .splitCsv(header:false, sep:'', strip:true)
            .map { it[0] }
            .set { ch_ids }

    } else if (params.id_list) {
        // Read in ids from ids_list
        Channel
            .fromPath(params.id_list)
            .splitCsv(
                header: false,
                sep:'',
                strip: true
            )
            .map { it[0] }
            .unique()
            .set { ch_ids }
    }

    //
    // MODULE: Get SRA run information for public database ids
    //
    SRA_IDS_TO_RUNINFO (
        ch_ids,
        params.ena_metadata_fields ?: ''
    )

    //
    // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
    //
    SRA_RUNINFO_TO_FTP (
        SRA_IDS_TO_RUNINFO.out.tsv
    )

    // Concatenate all metadata files into 1 mega file
    SRA_RUNINFO_TO_FTP.out.tsv
        .map { file ->
            file.text + '\n'
        }
        .collectFile (
            name:       "metadata.tsv",
            storeDir:   "${params.outdir}",
            keepHeader: true,
            skip:       1
        )

    if (!params.metadata_only) {

        SRA_RUNINFO_TO_FTP.out.tsv
            .splitCsv(
                header: true,
                sep:'\t'
            )
            .map {
                meta ->
                    meta.single_end = meta.single_end.toBoolean()
                    [ meta, [ meta.fastq_1, meta.fastq_2 ] ]
            }
            .unique()
            .branch {
                ftp: it[0].fastq_1  && !params.force_sratools_download
                sra: !it[0].fastq_1 || params.force_sratools_download
            }
            .set { ch_sra_reads }

        //
        // MODULE: If FTP link is provided in run information then download FastQ directly via FTP and validate with md5sums
        //
        SRA_FASTQ_FTP (
            ch_sra_reads.ftp
        )

        //
        // SUBWORKFLOW: Download sequencing reads without FTP links using sra-tools.
        //
        SRA_FASTQ_SRATOOLS (
            ch_sra_reads.sra.map { meta, reads -> [ meta, meta.run_accession ] }
        )

        SRA_FASTQ_FTP.out.fastq
            .mix(SRA_FASTQ_SRATOOLS.out.reads)
            .set{ ch_fastqs }

        //
        // MODULE: Stage FastQ files downloaded by SRA together and auto-create a samplesheet
        //
        SRA_TO_SAMPLESHEET (
            ch_fastqs,
            params.nf_core_pipeline ?: '',
            params.sample_mapping_fields
        )

        //
        // MODULE: Create a merged samplesheet across all samples for the pipeline
        //
        SRA_MERGE_SAMPLESHEET (
            SRA_TO_SAMPLESHEET.out.samplesheet.collect{it[1]},
            SRA_TO_SAMPLESHEET.out.mappings.collect{it[1]}
        )

        ch_fastqs
            .map { file -> file[1]}
            .flatten()
            .set { ch_fastqs_flat }
    }

    emit:
    fastqs = ch_fastqs_flat

}
