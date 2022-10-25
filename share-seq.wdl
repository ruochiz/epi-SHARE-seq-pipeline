version 1.0

# Import the sub-workflow for preprocessing the fastqs.
import "workflows/subwf-atac-single-organism.wdl" as share_atac
import "workflows/subwf-rna-single-organism.wdl" as share_rna
import "workflows/subwf-find-dorcs.wdl" as find_dorcs
import "tasks/share_task_html_report.wdl" as html_report

# WDL workflow for SHARE-seq

workflow ShareSeq {

    input {
        # Common inputs
        String prefix = "shareseq-project"
        String genome_name_input
        Int? cpus = 16


        # ATAC specific inputs
        Array[File?] read1_atac
        Array[File?] read2_atac
        File? chrom_sizes
        File? idx_tar_atac
        File? tss_bed
        Int? cpus_atac

        Int? cutoff_atac = 100

        # RNA specific inputs
        Boolean multimappers = false
        Boolean include_multimappers = false
        Boolean include_introns = true
        Array[File?] read1_rna
        File? genes_annotation_bed
        File? gtf
        File? idx_tar_rna
        Int? cpus_rna
        String? gene_naming = "gene_name"

        # Group UMI
        Boolean? remove_single_umi = false
        String? mode = "fast"
        Int? cutoff_rna = 100

        # Lib_size QC
        Boolean qc = false


        # DORCs specific inputs
        File? peak_set
        Int? cpus_dorcs
        String save_plots_to_dir = "TRUE"
        String? dorcs_output_filename

        # Seurat filters
        Int minFeature_RNA = 200
        Int maxFeature_RNA = 2500
        Float percentMT_RNA = 5
        Int minCells_RNA = 3

        # DORCs filter
        Int dorcGeneCutOff = 10
        Float fripCutOff = 0.3
        Float corrPVal = 0.05
        Int topNGene = 20

        # Regulatory region around TSS. Default is +/- 50Kb
        Int windowPadSize = 50000
        #Int bootstraps = 100

        String docker_image_dorcs = "us.gcr.io/buenrostro-share-seq/dorcs_task_find_dorcs"
        Int? mem_gb_dorcs

        File human_genome_tsv = "gs://broad-buenrostro-pipeline-genome-annotations/GRCh38/genome_files_hg38.tsv"
        File mouse_genome_tsv = "gs://broad-buenrostro-pipeline-genome-annotations/mm10/genome_files_mm10.tsv"
    }

    String genome_name = if genome_name_input == "GRCh38" then "hg38" else genome_name_input

    Map[String, File] annotations = if genome_name == "mm10" then read_map(mouse_genome_tsv) else read_map(human_genome_tsv)
    Array[File] read1_atac_ = select_all(read1_atac)
    Array[File] read2_atac_ = select_all(read2_atac)
    File peak_set_ = select_first([peak_set, annotations["ccre"]])
    File idx_tar_atac_ = select_first([idx_tar_atac, annotations["bowtie2_idx_tar"]])
    File chrom_sizes_ = select_first([chrom_sizes, annotations["chrsz"]])
    File tss_bed_ = select_first([tss_bed, annotations["tss"]])
    
    Array[File] read1_rna_ = select_all(read1_rna)
    File idx_tar_rna_ = select_first([idx_tar_rna, annotations["star_idx_tar"]])
    File gtf_ = select_first([gtf, annotations["genesgtf"]])
    File genes_annotation_bed_ = select_first([genes_annotation_bed, annotations["genesbed"]])

    Boolean process_atac = if defined(read1_atac) then true else false
    Boolean process_rna = if defined(read1_rna) then true else false

    if ( process_rna ) {
        call share_rna.wf_rna as rna{
            input:
                read1 = read1_rna_,
                idx_tar = idx_tar_rna_,
                prefix = prefix,
                genome_name = genome_name,
                cpus = cpus_rna,
                # Update RGID
                multimappers = multimappers,
                # Assign features
                include_multimappers = include_multimappers,
                include_introns = include_introns,
                gtf = gtf_,
                gene_naming = gene_naming,
                # Group UMI
                remove_single_umi = remove_single_umi,
                mode = mode,
                cutoff = cutoff_rna,
                # Lib_size QC
                qc = qc,
                genes_annotation_bed = genes_annotation_bed_
        }
    }

    if ( process_atac ) {
        call share_atac.wf_atac as atac{
            input:
                read1 = read1_atac_,
                read2 = read2_atac_,
                chrom_sizes = chrom_sizes_,
                idx_tar = idx_tar_atac_,
                tss_bed = tss_bed_,
                peak_set = peak_set_,
                prefix = prefix,
                genome_name = genome_name,
                cutoff = cutoff_atac,
                cpus = cpus_atac
        }
    }
    
    if ( process_atac && process_rna ) {
        call find_dorcs.wf_dorcs as dorcs{
            input:
                rna_matrix = rna.share_rna_h5_matrix,
                atac_fragments = atac.share_atac_fragments_filtered,
                peak_file = peak_set_,

                genome = genome_name,
                n_cores = cpus_dorcs,
                save_plots_to_dir = save_plots_to_dir,
                output_filename = dorcs_output_filename,
                prefix = prefix,

                minFeature_RNA = minFeature_RNA,
                maxFeature_RNA = maxFeature_RNA,
                percentMT_RNA = percentMT_RNA,
                minCells_RNA = minCells_RNA,

                dorcGeneCutOff = dorcGeneCutOff,
                fripCutOff = fripCutOff,
                corrPVal = corrPVal,
                topNGene = topNGene,

                windowPadSize = windowPadSize,
                mem_gb = mem_gb_dorcs
        }
    }

    call html_report.html_report as html_report {
        input:
            atac_total_reads = atac.share_atac_total_reads,
            atac_aligned_uniquely = atac.share_atac_aligned_uniquely,
            atac_unaligned = atac.share_atac_unaligned,
            atac_feature_reads = atac.share_atac_feature_reads,
            atac_duplicate_reads = atac.share_atac_duplicate_reads,
            rna_total_reads = rna.share_rna_total_reads,
            rna_aligned_uniquely = rna.share_rna_aligned_uniquely,
	          rna_aligned_multimap = rna.share_rna_aligned_multimap,
            rna_unaligned = rna.share_rna_unaligned,
            rna_feature_reads = rna.share_rna_feature_reads,
            rna_duplicate_reads = rna.share_rna_duplicate_reads,   

            ## JPEG files to be encoded and appended to html
            # RNA plots
            image_files = [rna.share_rna_qc_library_plot, rna.share_rna_seurat_raw_violin_plot, rna.share_rna_seurat_raw_qc_scatter_plot, rna.share_rna_seurat_filtered_violin_plot, rna.share_rna_seurat_filtered_qc_scatter_plot, rna.share_rna_seurat_variable_genes_plot, rna.share_rna_seurat_PCA_dim_loadings_plot, rna.share_rna_seurat_PCA_plot, rna.share_rna_seurat_heatmap_plot, rna.share_rna_seurat_jackstraw_plot, rna.share_rna_seurat_elbow_plot, rna.share_rna_seurat_umap_cluster_plot, rna.share_rna_seurat_umap_rna_count_plot, rna.share_rna_seurat_umap_gene_count_plot, rna.share_rna_seurat_umap_mito_plot, atac.share_atac_qc_library_plot, atac.share_atac_qc_hist_plot, atac.share_atac_qc_tss_enrichment, atac.share_atac_archr_gene_heatmap_plot, atac.share_atac_archr_raw_tss_enrichment, atac.share_atac_archr_filtered_tss_enrichment, atac.share_atac_archr_raw_fragment_size_plot, atac.share_atac_archr_filtered_fragment_size_plot, atac.share_atac_archr_umap_doublets, atac.share_atac_archr_umap_cluster_plot, atac.share_atac_archr_umap_doublets, atac.share_atac_archr_umap_num_frags_plot, atac.share_atac_archr_umap_tss_score_plot, atac.share_atac_archr_umap_frip_plot,atac.share_atac_archr_gene_heatmap_plot, atac.share_atac_archr_strict_raw_tss_enrichment, atac.share_atac_archr_strict_filtered_tss_enrichment, atac.share_atac_archr_strict_raw_fragment_size_plot, atac.share_atac_archr_strict_filtered_fragment_size_plot, atac.share_atac_archr_strict_umap_doublets, atac.share_atac_archr_strict_umap_cluster_plot, atac.share_atac_archr_umap_doublets, atac.share_atac_archr_strict_umap_num_frags_plot, atac.share_atac_archr_strict_umap_tss_score_plot, atac.share_atac_archr_strict_umap_frip_plot,atac.share_atac_archr_strict_gene_heatmap_plot, dorcs.j_plot],

            ## Links to files and logs to append to end of html
            log_files = [rna.share_rna_alignment_log, rna.share_rna_featurecount_exon_txt, rna.share_rna_featurecount_intron_txt, rna.share_rna_qc_reads_distribution, rna.share_rna_qc_reads_distribution2, rna.share_rna_umi_rm_dup_log, rna.share_rna_seurat_notebook_log, atac.share_atac_alignment_log, atac.share_atac_archr_notebook_log, dorcs.dorcs_notebook_log, rna.share_rna_alignment_raw]
    }

    output{
        File? share_rna_alignment_raw = rna.share_rna_alignment_raw
        File? share_rna_alignment_index = rna.share_rna_alignment_index
        File? share_rna_alignment_log = rna.share_rna_alignment_log

        File? share_rna_reheaded_alignment = rna.share_rna_reheaded_alignment
        File? share_rna_reheaded_alignment_index = rna.share_rna_reheaded_alignment_index

        File? share_rna_featurecount_alignment = rna.share_rna_featurecount_alignment
        File? share_rna_featurecount_alignment_index = rna.share_rna_featurecount_alignment_index
        #File? share_rna_featurecount_log = rna.share_rna_featurecount_log
        File? share_rna_featurecount_exon_txt = rna.share_rna_featurecount_exon_txt
        File? share_rna_featurecount_intron_txt = rna.share_rna_featurecount_intron_txt
        #File share_rna_featurecount_summary = rna.share_rna_featurecount_summary

        File? share_rna_umi_barcodes = rna.share_rna_umi_barcodes
        File? share_rna_umi_bed_filtered = rna.share_rna_umi_bed_filtered
        File? share_rna_umi_bed_unfiltered = rna.share_rna_umi_bed_unfiltered
        File? share_rna_umi_counts_filtered = rna.share_rna_umi_bed_unfiltered
        File? share_rna_umi_counts_unfiltered = rna.share_rna_umi_counts_unfiltered
        File? share_rna_umi_rm_dup_log = rna.share_rna_umi_rm_dup_log

        File? share_rna_qc_reads_distribution = rna.share_rna_qc_reads_distribution
        File? share_rna_qc_reads_distribution2 = rna.share_rna_qc_reads_distribution2
        File? share_rna_qc_reads_distribution_plot = rna.share_rna_qc_reads_distribution_plot

        File? share_rna_qc_library_counts = rna.share_rna_qc_library_counts
        File? share_rna_qc_library_duplicates = rna.share_rna_qc_library_duplicates
        File? share_rna_qc_library_plot = rna.share_rna_qc_library_plot
        File? share_rna_h5_matrix = rna.share_rna_h5_matrix
        File? share_rna_seurat_notebook_output = rna.share_rna_seurat_notebook_output
        File? share_rna_seurat_notebook_log = rna.share_rna_seurat_notebook_log
        File? share_rna_seurat_filtered_violin_plot = rna.share_rna_seurat_filtered_violin_plot
        File? share_rna_seurat_filtered_qc_scatter_plot = rna.share_rna_seurat_filtered_qc_scatter_plot
        File? share_rna_seurat_variable_genes_plot = rna.share_rna_seurat_variable_genes_plot
        File? share_rna_seurat_PCA_dim_loadings_plot = rna.share_rna_seurat_PCA_dim_loadings_plot
        File? share_rna_seurat_PCA_plot = rna.share_rna_seurat_PCA_plot
        File? share_rna_seurat_heatmap_plot = rna.share_rna_seurat_heatmap_plot
        File? share_rna_seurat_jackstraw_plot = rna.share_rna_seurat_jackstraw_plot
        File? share_rna_seurat_elbow_plot = rna.share_rna_seurat_elbow_plot
        File? share_rna_seurat_umap_cluster_plot = rna.share_rna_seurat_umap_cluster_plot
        File? share_rna_seurat_obj = rna.share_rna_seurat_obj
        File? share_rna_plots_zip = rna.share_rna_plots_zip

        File? share_atac_alignment_raw = atac.share_atac_alignment_raw
        File? share_atac_alignment_raw_index = atac.share_atac_alignment_raw_index
        File? share_atac_alignment_log = atac.share_atac_alignment_log

        File? share_atac_alignment_filtered = atac.share_atac_alignment_filtered
        File? share_atac_alignment_filtered_index = atac.share_atac_alignment_filtered_index
        File? share_atac_fragments_raw = atac.share_atac_fragments_raw


        File? share_atac_barcodes = atac.share_atac_barcodes
        File? share_atac_fragments_filtered = atac.share_atac_fragments_filtered
        File? share_atac_counts_raw = atac.share_atac_counts_raw
        File? share_atac_counts_filtered = atac.share_atac_counts_filtered

        File? share_atac_qc_library_counts = atac.share_atac_qc_library_counts
        File? share_atac_qc_library_duplicates = atac.share_atac_qc_library_duplicates
        File? share_atac_qc_library_plot = atac.share_atac_qc_library_plot

        File? share_atac_qc_final = atac.share_atac_qc_final
        File? share_atac_qc_hist_plot = atac.share_atac_qc_hist_plot
        File? share_atac_qc_hist_txt = atac.share_atac_qc_hist_txt
        File? share_atac_qc_tss_enrichment = atac.share_atac_qc_tss_enrichment

        File? share_atac_archr_notebook_output = atac.share_atac_archr_notebook_output
        File? share_atac_archr_notebook_log = atac.share_atac_archr_notebook_log
        File? share_atac_archr_gene_heatmap_plot = atac.share_atac_archr_gene_heatmap_plot
        File? share_atac_archr_raw_tss_enrichment = atac.share_atac_archr_raw_tss_enrichment
        File? share_atac_archr_filtered_tss_enrichment = atac.share_atac_archr_filtered_tss_enrichment
        File? share_atac_archr_filtered_fragment_size_plot = atac.share_atac_archr_filtered_fragment_size_plot
        File? share_atac_archr_umap_doublets = atac.share_atac_archr_umap_doublets
        File? share_atac_archr_umap_cluster_plot = atac.share_atac_archr_umap_cluster_plot
        File? share_atac_archr_arrow = atac.share_atac_archr_arrow
        File? share_atac_archr_obj = atac.share_atac_archr_obj
        File? share_atac_archr_plots_zip = atac.share_atac_archr_plots_zip

        File? dorcs_notebook_output = dorcs.dorcs_notebook_output
        File? dorcs_notebook_log = dorcs.dorcs_notebook_log
        File? seurat_violin_plot = dorcs.seurat_violin_plot
        File? j_plot = dorcs.j_plot
        File? plots_zip = dorcs.plots_zip
        File? dorcs_genes_summary = dorcs.dorcs_genes_summary
        File? dorcs_regions_summary = dorcs.dorcs_regions_summary

        File? html_summary = html_report.html_report_file
    }

}


# Task to report errors to user.
# From https://github.com/ENCODE-DCC/chip-seq-pipeline2/blob/master/chip.wdl
task raise_exception {
  input {
    String msg
    Array[String]? vals
  }
  command {
    echo -e "\n* Error: ${msg}\n" >&2
    echo -e "* Vals: ${sep=',' vals}\n" >&2
    exit 2
  }
  output {
    String error_msg = '${msg}'
  }
  runtime {
    maxRetries : 0
    cpu : 1
    memory : '2 GB'
    time : 1
    disks : 'local-disk 10 SSD'
    docker : 'encodedcc/chip-seq-pipeline:v2.2.1'
  }
}
