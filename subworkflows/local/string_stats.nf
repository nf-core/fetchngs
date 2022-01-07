include { CONSENSUS_ANCHORS     } from '../../modules/local/consensus_anchors'
include { SIGNIF_ANCHORS        } from '../../modules/local/signif_anchors'
include { ADJACENT_KMERS        } from '../../modules/local/adjacent_kmers'

workflow STRING_STATS {
    take:
    ch_fastq_anchors

    main:

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
            file.text
        }
        .collectFile (
            name:       "signif_anchors_${params.direction}_qval_${params.q_val}.tsv",
            storeDir:   "${params.outdir}/string_stats"
        )
        .set { ch_signif_anchors }

    //
    // MODULE: Run dgmfinder on fastqs
    //
    CONSENSUS_ANCHORS (
        ch_fastq_anchors,
        params.looklength
    )

    //
    // MODULE: Extract adjacent anchors
    //
    ADJACENT_KMERS (
        ch_signif_anchors,
        params.direction,
        params.kmer_size,
        params.adj_dist,
        params.adj_len,
        ch_fastq_anchors
    )

    // Concatenate all adjacent anchors
    ADJACENT_KMERS.out.tsv
        .view()
        .map { file ->
            file.text + '\n'
        }
        .collectFile (
            name:       "adjacent_kmers_${params.direction}_qval_${params.q_val}.tsv",
            storeDir:   "${params.outdir}/string_stats"
        )
}
