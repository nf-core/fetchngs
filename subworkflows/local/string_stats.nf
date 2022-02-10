include { SAMPLE_FASTQ                  } from '../../modules/local/sample_fastq'
include { SIGNIF_ANCHORS                } from '../../modules/local/signif_anchors'
include { MERGE_SIGNIF_ANCHORS                } from '../../modules/local/merge_signif_anchors'
include { PARSE_ANCHORS                 } from '../../modules/local/parse_anchors'
include { ADJACENT_KMERS                } from '../../modules/local/adjacent_kmers'
include { MERGE_ADJACENT_KMER_COUNTS    } from '../../modules/local/merge_adjacent_kmer_counts'


workflow STRING_STATS {
    take:
    ch_fastq_anchors
    num_input_lines

    main:

    //
    // MODULE: Extract significant anchors
    //
    SIGNIF_ANCHORS (
        ch_fastq_anchors,
        params.direction,
        params.q_val
    )

    // Make samplesheet of all signif_anchors files
    SIGNIF_ANCHORS.out.tsv
        .collectFile() { file ->
            def X=file; X.toString() + '\n'
        }
        .set{ ch_signif_anchors_samplesheet }

    //
    // MODULE: Merge all signif_anchors
    //
    MERGE_SIGNIF_ANCHORS (
        ch_signif_anchors_samplesheet,
        params.direction,
        params.q_val,
        params.num_anchors
    )

    signif_anchors = MERGE_SIGNIF_ANCHORS.out.tsv.first()

    //
    // MODULE: Get consensus anchors and adj_anchors
    //
    PARSE_ANCHORS (
        signif_anchors,
        num_input_lines,
        params.looklength,
        params.kmer_size,
        params.direction,
        ch_fastq_anchors
    )

    // Make samplesheet of all adjacent_kmer_counts files
    PARSE_ANCHORS.out.tsv
        .collectFile() { file ->
            file.toString() + '\n'
        }
        .set{ ch_adj_kmer_counts_samplesheet }

    //
    // MODULE: Merge all adjacent_kmer_counts into one mega table
    //
    MERGE_ADJACENT_KMER_COUNTS (
        ch_adj_kmer_counts_samplesheet,
        signif_anchors
    )


}
