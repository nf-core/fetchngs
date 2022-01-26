include { DGMFINDER_ANALYSIS    } from '../../modules/local/dgmfinder_analysis'

workflow DGMFINDER {
    take:
    ch_fastqs

    main:

    //
    // MODULE: Run dgmfinder on fastqs
    //
    DGMFINDER_ANALYSIS (
        ch_fastqs,
        params.ann_file,
        params.kmer_size,
        params.max_dgmfinder_reads
    )

    emit:
    fastq_anchors = DGMFINDER_ANALYSIS.out.fastq_anchors

}
