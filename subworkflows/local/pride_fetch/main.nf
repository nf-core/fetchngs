//
// Subworkflow to fetch file metadata for PRIDE (PXD) ids
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS/FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { PRIDEPY_STREAMFILESMETADATA } from '../../../modules/local/pridepy/streamfilesmetadata'

workflow PRIDE_FETCH {
    take:
    ids // channel: [ ids ]

    main:
    PRIDEPY_STREAMFILESMETADATA(ids.map { id -> [[id: id], id] })

    emit:
    metadata = PRIDEPY_STREAMFILESMETADATA.out.json // channel: [ val(meta), path(json) ]
}
