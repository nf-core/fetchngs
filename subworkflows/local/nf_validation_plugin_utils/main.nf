//
// Subworkflow that uses the nf-validation plugin to render help text and parameter summary
//

/*
========================================================================================
    IMPORT NF-VALIDATION PLUGIN
========================================================================================
*/

include { paramsHelp; paramsSummaryLog; paramsSummaryMap; validateParameters } from 'plugin/nf-validation'

/*
========================================================================================
    SUBWORKFLOW DEFINITION
========================================================================================
*/

workflow NF_VALIDATION_PLUGIN_UTILS {

    take:
    print_help       // bool
    workflow_command // string: default commmand used to run pipeline
    pre_help_text    // string: string to be printed before help text and summary log
    post_help_text   // string: string to be printed after help text and summary log
    validate_params  // bool

    main:

    //
    // Print help message if needed
    //
    if (print_help && workflow_command) {
        log.info pre_help_text + paramsHelp(workflow_command) + post_help_text
        System.exit(0)
    }

    //
    // Print parameter summary to stdout
    //
    log.info pre_help_text + paramsSummaryLog(workflow) + post_help_text

    //
    // Validate parameters relative to the parameter JSON schema
    //
    if (validate_params){
        validateParameters()
    }

    emit:
    summary_params = paramsSummaryMap(workflow)
}
