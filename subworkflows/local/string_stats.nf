include { CONSENSUS_ANCHORS     } from '../../modules/local/consensus_anchors'
include { SIGNIF_ANCHORS        } from '../../modules/local/signif_anchors'
include { ADJACENT_ANCHORS      } from '../../modules/local/adjacent_anchors'

workflow STRING_STATS {
    take:
    ch_fastq_anchors

    main:

    //
    // MODULE: Run dgmfinder on fastqs
    //
    CONSENSUS_ANCHORS (
        ch_fastq_anchors,
        params.looklength
    )

}
