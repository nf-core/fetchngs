//
// This file holds several functions specific to the main.nf workflow in the nf-core/fetchngs pipeline
//

import nextflow.Nextflow

class WorkflowMain {

    //
    // Citation string for pipeline
    //
    public static String citation(workflow) {
        return "If you use ${workflow.manifest.name} for your analysis please cite:\n\n" +
            "* The pipeline\n" +
            "  https://doi.org/10.5281/zenodo.5070524\n\n" +
            "* The nf-core framework\n" +
            "  https://doi.org/10.1038/s41587-020-0439-x\n\n" +
            "* Software dependencies\n" +
            "  https://github.com/${workflow.manifest.name}/blob/master/CITATIONS.md"
    }


    //
    // Validate parameters and print summary to screen
    //
    public static void initialise(workflow, params, log) {

        // Print workflow version and exit on --version
        if (params.version) {
            String workflow_version = NfcoreTemplate.version(workflow)
            log.info "${workflow.manifest.name} ${workflow_version}"
            System.exit(0)
        }

        // Check that a -profile or Nextflow config has been provided to run the pipeline
        NfcoreTemplate.checkConfigProvided(workflow, log)

        // Check that conda channels are set-up correctly
        if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
            Utils.checkCondaChannels(log)
        }

        // Check AWS batch settings
        NfcoreTemplate.awsBatch(workflow, params)

        // Check input has been provided
        if (!params.input) {
            Nextflow.error("Please provide an input file containing ids to the pipeline - one per line e.g. '--input ids.csv'")
        }

        // Check valid input_type has been provided
        def input_types = ['sra', 'synapse']
        if (!input_types.contains(params.input_type)) {
            Nextflow.error("Invalid option: '${params.input_type}'. Valid options for '--input_type': ${input_types.join(', ')}.")
        }
    }

    // Check if input ids are from the SRA
    public static Boolean isSraId(input) {
        def is_sra = false
        def total_ids = 0
        def no_match_ids = []
        def pattern = /^(((SR|ER|DR)[APRSX])|(SAM(N|EA|D))|(PRJ(NA|EB|DB))|(GS[EM]))(\d+)$/
        input.eachLine { line ->
            total_ids += 1
            if (!(line =~ pattern)) {
                no_match_ids << line
            }
        }

        def num_match = total_ids - no_match_ids.size()
        if (num_match > 0) {
            if (num_match == total_ids) {
                is_sra = true
            } else {
                Nextflow.error("Mixture of ids provided via --input: ${no_match_ids.join(', ')}\nPlease provide either SRA / ENA / GEO / DDBJ or Synapse ids!")
            }
        }
        return is_sra
    }

    // Check if input ids are from the Synapse platform
    public static Boolean isSynapseId(input) {
        def is_synapse = false
        def total_ids = 0
        def no_match_ids = []
        def pattern = /^syn\d{8}$/
        input.eachLine { line ->
            total_ids += 1
            if (!(line =~ pattern)) {
                no_match_ids << line
            }
        }

        def num_match = total_ids - no_match_ids.size()
        if (num_match > 0) {
            if (num_match == total_ids) {
                is_synapse = true
            } else {
                Nextflow.error("Mixture of ids provided via --input: ${no_match_ids.join(', ')}\nPlease provide either SRA / ENA / GEO / DDBJ or Synapse ids!")
            }
        }
        return is_synapse
    }
}
