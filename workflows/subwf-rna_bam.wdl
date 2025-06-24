version 1.0

import "../tasks/task_starsolo.wdl" as task_starsolo

# Import the tasks called by the pipeline
workflow wf_rna_bam {
    meta {
        version: 'v0.1'
        author: 'Eugenio Mattei (emattei@broadinstitute.org) and Sai Ma @ Broad Institute of MIT and Harvard'
        description: 'Broad Institute of MIT and Harvard SHARE-Seq pipeline: Sub-workflow to process the RNA portion of SHARE-seq libraries.'
    }

    input {
        # RNA sub-workflow inputs
        String? subpool
        String prefix
        String genome_name
        String chemistry
        File whitelist
        Array[File] read1
        Array[File] read2

        # Do we want to use the multimappers assigned with EM method
        Boolean multimappers = false

        # Align-specific inputs
        File idx_tar
        String? barcode_tag
        String soloUMIdedup = "1MM_All"
        String soloMultiMappers = "Unique EM"
        Int outFilterMultimapNmax = 20
        Float outFilterScoreMinOverLread = 0.3
        Float outFilterMatchNminOverLread = 0.3
        Int? winAnchorMultimapNmax
        Float? outFilterMismatchNoverReadLmax
        Int? outFilterScoreMin
        String? soloBarcodeMate # 2 for SHARE
        String? soloCBposition # 1_-83_1_-76 1_-45_1_-38 1_-7_1_0 for SHARE
        String? clip5pNbases  # 0 34 for SHARE
        String? limitBAMsortRAM = "31232551044"
        String? limitOutSJcollapsed = "4000000"
        # Runtime parameters
        Int? align_cpus
        Float? align_disk_factor
        Float? align_memory_factor
        String? align_docker_image
        
    }

    call task_starsolo.rna_align as align {
        input:
            chemistry = chemistry,
            fastq_R1 = read1,
            fastq_R2 = read2,
            whitelist = whitelist,
            soloMultiMappers = soloMultiMappers,
            soloUMIdedup = soloUMIdedup,
            outFilterMultimapNmax = outFilterMultimapNmax,
            outFilterScoreMinOverLread = outFilterScoreMinOverLread,
            outFilterMatchNminOverLread = outFilterMatchNminOverLread,
            winAnchorMultimapNmax = winAnchorMultimapNmax,
            outFilterMismatchNoverReadLmax = outFilterMismatchNoverReadLmax,
            outFilterScoreMin = outFilterScoreMin,
            soloBarcodeMate = soloBarcodeMate,
            soloCBposition = soloCBposition,
            clip5pNbases = clip5pNbases,
            limitBAMsortRAM=limitBAMsortRAM,
            limitOutSJcollapsed=limitOutSJcollapsed,
            genome_name = genome_name,
            genome_index_tar = idx_tar,
            prefix = prefix,
            cpus = align_cpus,
            disk_factor = align_disk_factor,
            memory_factor = align_memory_factor,
            docker_image = align_docker_image
    }

    output {
        File? starsolo_output_bam = align.output_bam
        File? starsolo_rna_alignment_log = align.log_final_out
        File? starsolo_log_out = align.log_out
        File? starsolo_log_progress_out = align.log_progress_out
        File? starsolo_output_sj = align.output_sj
        File? starsolo_barcodes_stats = align.barcodes_stats
        File? starsolo_features_stats = align.features_stats
        File? starsolo_summary_csv = align.summary_csv
        File? starsolo_umi_per_cell = align.umi_per_cell
        File? starsolo_raw_tar = align.raw_tar
    }
}