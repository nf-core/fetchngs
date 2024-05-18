/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC_MAPPINGS_CONFIG } from '../../modules/local/multiqc_mappings_config'
include { SRA_FASTQ_FTP           } from '../../modules/local/sra_fastq_ftp'
include { SRA_IDS_TO_RUNINFO      } from '../../modules/local/sra_ids_to_runinfo'
include { SRA_RUNINFO_TO_FTP      } from '../../modules/local/sra_runinfo_to_ftp'
include { ASPERA_CLI              } from '../../modules/local/aspera_cli'
include { SRA_TO_SAMPLESHEET      } from '../../modules/local/sra_to_samplesheet'
include { softwareVersionsToYAML  } from '../../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS } from '../../subworkflows/nf-core/fastq_download_prefetch_fasterqdump_sratools'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT RECORD TYPES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { Sample } from '../../types/types'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SRA {

    take:
    ids                         // List<String>
    ena_metadata_fields         // String
    sample_mapping_fields       // String
    nf_core_pipeline            // String
    nf_core_rnaseq_strandedness // String
    download_method             // String enum: 'aspera' | 'ftp' | 'sratools'
    skip_fastq_download         // boolean
    dbgap_key                   // String
    aspera_cli_args             // String
    sra_fastq_ftp_args          // String
    sratools_fasterqdump_args   // String
    sratools_pigz_args          // String
    outdir                      // String

    main:
    ids                                                         // Channel<String>
        //
        // MODULE: Get SRA run information for public database ids
        //
        |> map { id ->
            SRA_IDS_TO_RUNINFO ( id, ena_metadata_fields )
        }                                                       // Channel<Path>
        //
        // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
        //
        |> map(SRA_RUNINFO_TO_FTP)                              // Channel<Path>
        |> set { runinfo_ftp }                                  // Channel<Path>
        |> flatMap { tsv ->
            splitCsv(tsv, header:true, sep:'\t')
        }                                                       // Channel<Map>
        |> map { meta ->
            meta + [single_end: meta.single_end.toBoolean()]
        }                                                       // Channel<Map>
        |> unique                                               // Channel<Map>
        |> set { sra_metadata }                                 // Channel<Map>

    if (!skip_fastq_download) {

        //
        // MODULE: If FTP link is provided in run information then download FastQ directly via FTP and validate with md5sums
        //
        sra_metadata
            |> filter { meta ->
                getDownloadMethod(meta, download_method) == 'ftp'
            }                                                   // Channel<Map>
            |> map { meta ->
                def fastq = [ file(meta.fastq_1), file(meta.fastq_2) ]
                SRA_FASTQ_FTP ( meta, fastq, sra_fastq_ftp_args )
            }                                                   // Channel<ProcessOut(meta: Map, fastq: List<Path>, md5: List<Path>)>
            |> set { ftp_samples }                              // Channel<ProcessOut(meta: Map, fastq: List<Path>, md5: List<Path>)>

        //
        // SUBWORKFLOW: Download sequencing reads without FTP links using sra-tools.
        //
        sra_metadata
            |> filter { meta ->
                getDownloadMethod(meta, download_method) == 'sratools'
            }                                                   // Channel<Map>
            |> FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS (
                dbgap_key ? file(dbgap_key, checkIfExists: true) : [],
                sratools_fasterqdump_args,
                sratools_pigz_args )                            // Channel<ProcessOut(meta: Map, fastq: List<Path>)>
            |> set { sratools_samples }                         // Channel<ProcessOut(meta: Map, fastq: List<Path>)>
 
        //
        // MODULE: If Aspera link is provided in run information then download FastQ directly via Aspera CLI and validate with md5sums
        //
        sra_metadata
            |> filter { meta ->
                getDownloadMethod(meta, download_method) == 'aspera'
            }                                                   // Channel<Map>
            |> map { meta ->
                def fastq = meta.fastq_aspera.tokenize(';').take(2).collect { name -> file(name) }
                ASPERA_CLI ( meta, fastq, 'era-fasp', aspera_cli_args )
            }                                                   // Channel<ProcessOut(meta: Map, fastq: List<Path>, md5: List<Path>)>
            |> set { aspera_samples }                           // Channel<ProcessOut(meta: Map, fastq: List<Path>, md5: List<Path>)>

        // Isolate FASTQ channel which will be added to emit block
        fastq = mix(
            ftp_samples         |> map { out -> new Sample(out.meta, out.fastq) },
            sratools_samples    |> map { out -> new Sample(out.meta, out.fastq) },
            aspera_samples      |> map { out -> new Sample(out.meta, out.fastq) }
        )

        md5 = mix(
            ftp_samples         |> map { out -> new Sample(out.meta, out.md5) },
            aspera_samples      |> map { out -> new Sample(out.meta, out.md5) }
        )

        fastq                                                   // Channel<Sample>
            |> map { sample ->
                def reads = sample.files
                def meta = sample.meta
                meta + [
                    fastq_1: reads[0] ? "${outdir}/fastq/${reads[0].getName()}" : '',
                    fastq_2: reads[1] && !meta.single_end ? "${outdir}/fastq/${reads[1].getName()}" : ''
                ]
            }                                                   // Channel<Map>
            |> set { sra_metadata }                             // Channel<Map>
    }

    //
    // MODULE: Stage FastQ files downloaded by SRA together and auto-create a samplesheet
    //
    sra_metadata                                            // Channel<Map>
        |> collect                                          // List<Map>
        |> { sra_metadata ->
            SRA_TO_SAMPLESHEET (
                sra_metadata,
                nf_core_pipeline,
                nf_core_rnaseq_strandedness,
                sample_mapping_fields )
        }                                                   // ProcessOut(samplesheet: Path, mappings: Path)
        |> set { index_files }                              // ProcessOut(samplesheet: Path, mappings: Path)

    samplesheet = index_files.samplesheet                   // Path
    mappings    = index_files.mappings                      // Path

    //
    // MODULE: Create a MutiQC config file with sample name mappings
    //
    sample_mappings = sample_mapping_fields
        ? MULTIQC_MAPPINGS_CONFIG ( mappings )              // Path
        : null

    //
    // Collate and save software versions
    //
    'versions'                                              // String
        |> Channel.topic                                    // Channel<Tuple3<String,String,String>>
        |> softwareVersionsToYAML                           // Channel<String>
        |> collect(sort: true)                              // List<String>
        |> exec('SOFTWARE_VERIONS') { versions ->
            def path = task.workDir.resolve('nf_core_fetchngs_software_mqc_versions.yml')
            mergeText(versions, path, newLine: true)
            return path
        }                                                   // Path
        |> set { versions_yml }                             // Path

    emit:
    samplesheet
    mappings
    sample_mappings
    sra_metadata

    publish:
    fastq           >> 'fastq/'
    md5             >> 'fastq/md5/'
    runinfo_ftp     >> 'metadata/'
    versions_yml    >> 'pipeline_info/'
    samplesheet     >> 'samplesheet/'
    mappings        >> 'samplesheet/'
    sample_mappings >> 'samplesheet/'
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

def getDownloadMethod(Map meta, String download_method) {
    // meta.fastq_aspera is a metadata string with ENA fasp links supported by Aspera
        // For single-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/ERR116/006/ERR1160846/ERR1160846.fastq.gz'
        // For paired-end: 'fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_1.fastq.gz;fasp.sra.ebi.ac.uk:/vol1/fastq/SRR130/020/SRR13055520/SRR13055520_2.fastq.gz'
    if (meta.fastq_aspera && download_method == 'aspera')
        return 'aspera'
    if ((!meta.fastq_aspera && !meta.fastq_1) || download_method == 'sratools')
        return 'sratools'
    return 'ftp'
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
