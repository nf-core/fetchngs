//
// This file holds several functions specific to the workflow/sra.nf in the nf-core/fetchngs pipeline
//

import nextflow.Nextflow

class WorkflowSra {

    //
    // Check and validate parameters
    //
    public static void initialise(params, valid_params) {
        // Check minimal ENA fields are provided to download FastQ files
        def ena_metadata_fields = params.ena_metadata_fields ? params.ena_metadata_fields.split(',').collect{ it.trim().toLowerCase() } : valid_params['ena_metadata_fields']
        if (!ena_metadata_fields.containsAll(valid_params['ena_metadata_fields'])) {
            Nextflow.error("Invalid option: '${params.ena_metadata_fields}'. Minimally required fields for '--ena_metadata_fields': '${valid_params['ena_metadata_fields'].join(',')}'")
        }
    }

    //
    // Print a warning after pipeline has completed
    //
    public static void curateSamplesheetWarn(log) {
        log.warn "=============================================================================\n" +
            "  Please double-check the samplesheet that has been auto-created by the pipeline.\n\n" +
            "  Public databases don't reliably hold information such as strandedness\n" +
            "  information, controls etc\n\n" +
            "  All of the sample metadata obtained from the ENA has been appended\n" +
            "  as additional columns to help you manually curate the samplesheet before\n" +
            "  running nf-core/other pipelines.\n" +
            "==================================================================================="
    }
}
