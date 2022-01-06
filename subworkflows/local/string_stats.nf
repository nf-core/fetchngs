include { CONSENSUS_ANCHORS     } from '../../modules/local/consensus_anchors'
include { SIGNIF_ANCHORS        } from '../../modules/local/signif_anchors'
include { ADJACENT_ANCHORS      } from '../../modules/local/adjacent_anchors'

workflow STRING_STATS {
    take:
    ch_fastq_anchors

    main:

    //
    // MODULE: Get consensus anchors and stats
    //
    CONSENSUS_ANCHORS (
        ch_fastq_anchors
        params.looklength
    )

    //
    // MODULE: Extract significant anchors
    //
    SIGNIF_ANCHORS (
        ch_fastq_anchors,
        params.direction,
        params.q_val
    )

    // Concatenate all significant anchors
    SIGNIF_ANCHORS.out.tsv
        .map { file ->
            file.text + '\n'
        }
        .collectFile (
            name:       "signif_anchors_${params.direction}_qval_${params.q_val}.tsv",
            storeDir:   "${params.outdir}/string_stats"
        )
        .set { ch_signif_anchors }

    //
    // MODULE: Extract adjacent anchors
    //
    ADJACENT_ANCHORS (
        ch_signif_anchors,
        ch_fastq_anchors,
        params.direction,
        params.kmer_size,
        params.adj_dist,
        params.adj_len
    )

    // Concatenate all adjacent anchors
    ADJACENT_ANCHORS.out.tsv
        .map { file ->
            file.text + '\n'
        }
        .collectFile (
            name:       "adjacent_anchors_${params.direction}_qval_${params.q_val}.tsv",
            storeDir:   "${params.outdir}/string_stats"
        )

    emit:

}
