/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def valid_params = [
    ena_metadata_fields : ['run_accession', 'experiment_accession', 'library_layout', 'fastq_ftp', 'fastq_md5']
]

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowSra.initialise(params, log, valid_params)

// Check mandatory parameters
if (params.input) {
    Channel
        .from(file(params.input, checkIfExists: true))
        .splitCsv(header:false, sep:'', strip:true)
        .map { it[0] }
        .unique()
        .set { ch_ids }
} else {
    exit 1, 'Input file with public database ids not specified!'
}

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

include { SRA_IDS_TO_RUNINFO      } from '../modules/local/sra_ids_to_runinfo'      addParams( options: modules['sra_ids_to_runinfo']      )
include { SRA_RUNINFO_TO_FTP      } from '../modules/local/sra_runinfo_to_ftp'      addParams( options: modules['sra_runinfo_to_ftp']      )
include { SRA_FASTQ_FTP           } from '../modules/local/sra_fastq_ftp'           addParams( options: modules['sra_fastq_ftp']           )
include { SRA_TO_SAMPLESHEET      } from '../modules/local/sra_to_samplesheet'      addParams( options: modules['sra_to_samplesheet'], results_dir: modules['sra_fastq_ftp'].publish_dir )
include { SRA_MERGE_SAMPLESHEET   } from '../modules/local/sra_merge_samplesheet'   addParams( options: modules['sra_merge_samplesheet']   )
include { MULTIQC_MAPPINGS_CONFIG } from '../modules/local/multiqc_mappings_config' addParams( options: modules['multiqc_mappings_config'] )

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main' addParams( options: [publish_files : ['_versions.yml':'']] )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow SRA {

    ch_versions = Channel.empty()

    //
    // MODULE: Get SRA run information for public database ids
    //
    SRA_IDS_TO_RUNINFO (
        ch_ids,
        params.ena_metadata_fields ?: ''
    )
    ch_versions = ch_versions.mix(SRA_IDS_TO_RUNINFO.out.versions.first())

    //
    // MODULE: Parse SRA run information, create file containing FTP links and read into workflow as [ meta, [reads] ]
    //
    SRA_RUNINFO_TO_FTP (
        SRA_IDS_TO_RUNINFO.out.tsv
    )
    ch_versions = ch_versions.mix(SRA_RUNINFO_TO_FTP.out.versions.first())

    SRA_RUNINFO_TO_FTP
        .out
        .tsv
        .splitCsv(header:true, sep:'\t')
        .map {
            meta ->
                meta.single_end = meta.single_end.toBoolean()
                [ meta, [ meta.fastq_1, meta.fastq_2 ] ]
        }
        .unique()
        .set { ch_sra_reads }
    ch_versions = ch_versions.mix(SRA_RUNINFO_TO_FTP.out.versions.first())

    if (!params.skip_fastq_download) {
        //
        // MODULE: If FTP link is provided in run information then download FastQ directly via FTP and validate with md5sums
        //
        SRA_FASTQ_FTP (
            ch_sra_reads.map { meta, reads -> if (meta.fastq_1)  [ meta, reads ] }
        )
        ch_versions = ch_versions.mix(SRA_FASTQ_FTP.out.versions.first())

        //
        // MODULE: Stage FastQ files downloaded by SRA together and auto-create a samplesheet
        //
        SRA_TO_SAMPLESHEET (
            SRA_FASTQ_FTP.out.fastq,
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
        ch_versions = ch_versions.mix(SRA_MERGE_SAMPLESHEET.out.versions)

        //
        // MODULE: Create a MutiQC config file with sample name mappings
        //
        if (params.sample_mapping_fields) {
            MULTIQC_MAPPINGS_CONFIG (
                SRA_MERGE_SAMPLESHEET.out.mappings
            )
            ch_versions = ch_versions.mix(MULTIQC_MAPPINGS_CONFIG.out.versions)
        }

        //
        // If ids don't have a direct FTP download link write them to file for download outside of the pipeline
        //
        def no_ids_file = ["${params.outdir}", "${modules['sra_fastq_ftp'].publish_dir}", "IDS_NOT_DOWNLOADED.txt" ].join(File.separator)
        ch_sra_reads
            .map { meta, reads -> if (!meta.fastq_1) "${meta.id.split('_')[0..-2].join('_')}" }
            .unique()
            .collectFile(name: no_ids_file, sort: true, newLine: true)
    }

    //
    // MODULE: Pipeline reporting
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
    WorkflowSra.curateSamplesheetWarn(log)
}

/*
========================================================================================
    THE END
========================================================================================
*/