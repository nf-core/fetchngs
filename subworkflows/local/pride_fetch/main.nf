//
// Subworkflow to fetch file metadata and download files for PRIDE ids
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { PRIDEPY_STREAMFILESMETADATA } from '../../../modules/local/pridepy/streamfilesmetadata'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { PRIDEPY_DOWNLOADFILE        } from '../../../modules/nf-core/pridepy/downloadfile'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PRIDE_FETCH {
    take:
    ids             // channel: [ ids ]
    file_categories // val: comma-separated file categories to download, e.g. 'RAW,PEAK'
    skip_download   // val: boolean

    main:
    //
    // MODULE: Get the list of files of each PRIDE project
    //
    PRIDEPY_STREAMFILESMETADATA(ids.map { id -> [[id: id], id] })

    ch_files = channel.empty()

    if (!skip_download) {
        // One element per file to download: [ meta, file name, accession ]
        ch_to_download = PRIDEPY_STREAMFILESMETADATA.out.json
            .flatMap { meta, json -> filesToDownload(meta, json, file_categories) }

        //
        // MODULE: Download each selected file from PRIDE
        //
        PRIDEPY_DOWNLOADFILE(ch_to_download)
        ch_files = PRIDEPY_DOWNLOADFILE.out.file
    }

    emit:
    metadata = PRIDEPY_STREAMFILESMETADATA.out.json // channel: [ val(meta), path(json) ]
    files    = ch_files                             // channel: [ val(meta), path(file) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Select the files of a PRIDE project to download: the requested categories plus the SDRF, if any.
// Warns about requested categories that don't exist in the project.
//
def filesToDownload(meta, json, file_categories) {
    def records = new groovy.json.JsonSlurper().parseText(json.text)
    def wanted = file_categories.tokenize(',')

    def selected = records.findAll { record -> categoryOf(record) in wanted }
    def available = records.collect { record -> categoryOf(record) }.unique().sort()
    def missing = wanted - available
    if (missing) {
        log.warn("No files in categories ${missing.join(', ')} for ${meta.id}. Available categories: ${available.join(', ')}")
    }
    def sdrf = records.findAll { record -> categoryOf(record) == 'EXPERIMENTAL DESIGN' }

    return (selected + sdrf).collect { record ->
        [meta + [id: record.fileName, accession: meta.id, category: categoryOf(record)], record.fileName, meta.id]
    }
}

//
// Category of a PRIDE file record, e.g. 'RAW'
//
def categoryOf(record) {
    return record.fileCategory?.value
}
