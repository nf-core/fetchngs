include { SAMPLE_FASTQ                  } from '../../modules/local/sample_fastq'
include { SIGNIF_ANCHORS                } from '../../modules/local/signif_anchors'
include { CONSENSUS_ANCHORS             } from '../../modules/local/consensus_anchors'
include { ADJACENT_KMERS                } from '../../modules/local/adjacent_kmers'
include { MERGE_ADJACENT_KMER_COUNTS    } from '../../modules/local/merge_adjacent_kmer_counts'


workflow STRING_STATS {
    take:
    ch_fastq_anchors
    num_input_lines

    main:

    SAMPLE_FASTQ (
        ch_fastq_anchors
    )

    ch_sub_fastq_anchors = SAMPLE_FASTQ.out.fastq_anchors

    //
    // MODULE: Extract significant anchors
    //
    SIGNIF_ANCHORS (
        ch_sub_fastq_anchors,
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
        ch_signif_anchors,
        num_input_lines,
        params.looklength,
        params.kmer_size,
        ch_sub_fastq_anchors
    )

    // Concatenate all adjacent_kmer lists
    CONSENSUS_ANCHORS.out.tsv
        .map { file ->
            file.text + '\n'
        }
        .collectFile (
            keepHeader: true,
            skip:       1
        )
        .set { ch_adj_kmers }

    //
    // MODULE: Extract adjacent anchors
    //
    ADJACENT_KMERS (
        ch_adj_kmers,
        num_input_lines,
        params.kmer_size,
        ch_sub_fastq_anchors
    )

    // Make samplesheet of all adjacent_kmer_counts files
    ADJACENT_KMERS.out.tsv
        .collectFile() { file ->
            file.toString() + '\n'
        }
        .set{ ch_adj_kmer_counts_samplesheet }

    //
    // MODULE: Merge all adjacent_kmer_counts into one mega table
    //
    MERGE_ADJACENT_KMER_COUNTS (
        ch_adj_kmer_counts_samplesheet
    )


}
