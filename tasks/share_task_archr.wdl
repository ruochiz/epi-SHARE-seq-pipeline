version 1.0

task archr {
    meta {
        version: 'v0.1'
        author: 'Siddarth Wekhande (swekhand@broadinstitute.org) at Broad Institute of MIT and Harvard'
        description: 'Broad Institute of MIT and Harvard SHARE-Seq pipeline: run archr task'
    }

    input {
        #This tasks takes in an ATAC fragment file, processes using ArchR and creates plots

        #ArchR parameters
        File atac_frag
        String genome
        File peak_set

        #ArchR QC
        Int min_tss = 4
        Int min_frags = 100
        String add_tile_mat = "TRUE"
        String add_gene_score_mat = "TRUE"

        #ArchR Doublet paramaters
        String find_doublets = "FALSE"
        Int doublet_k = 10
        String doublet_knn_method = "UMAP"
        Int lsi_method = 1

        String copy_arrow_files = "TRUE"
        String iter_LSI_matrix = "TileMatrix"
        Int threads = 1
        String prefix = "prefix"

        #ArchR Plots parameters
        String marker_features_test = "wilcoxon"
        String heatmap_transpose = "TRUE"
        Int heatmap_label_n = 5

        String heatmap_cutoff = "'FDR <= 0.01 & Log2FC >= 0.5'" # Fix - use two float as parameters and create the string inside the task

        #papermill specific parameters
        String papermill = "TRUE"

        String output_filename = "${prefix}.atac.archr.notebook.${genome}.ipynb"
        #String docker_image = "us.gcr.io/buenrostro-share-seq/share_task_archr"
        String docker_image = "mshriver01/share_task_archr"
        String log_filename = "log/${prefix}.atac.archr.logfile.${genome}.txt"

        Float? disk_factor = 8.0
        Float? memory_factor = 4.0
    }
    
    # Determine the size of the input
    Float input_file_size_gb = size(atac_frag, "G") 

    # Determining memory size base on the size of the input files.
    Float mem_gb = 32.0 + memory_factor * input_file_size_gb

    # Determining disk size base on the size of the input files.
    Int disk_gb = round(50.0 + disk_factor * input_file_size_gb)

    # Determining disk type base on the size of disk.
    String disk_type = if disk_gb > 375 then "SSD" else "LOCAL"

    #Plot filepaths
    String plots_filepath = '${prefix}.atac.archr.plots.${genome}'
    String raw_tss_by_uniq_frags_plot = '${plots_filepath}/${prefix}.atac.archr.prefiltered_tss_by_uniq_frags.${genome}.png'
    String raw_frag_size_dist_plot = '${plots_filepath}/${prefix}.atac.archr.prefiltered_frag_size_dist.${genome}.png'
    String filtered_tss_by_uniq_frags_plot = '${plots_filepath}/${prefix}.atac.archr.postfiltered_tss_by_uniq_frags.${genome}.png'
    String filtered_frag_size_dist_plot = '${plots_filepath}/${prefix}.atac.archr.postfiltered_frag_size_dist.${genome}.png'
    String umap_cluster_plot = '${plots_filepath}/${prefix}.atac.archr.umap_clusters.${genome}.png'
    String umap_num_frags_plot = '${plots_filepath}/${prefix}.atac.archr.umap_num_frags.${genome}.png'
    String umap_tss_score_plot = '${plots_filepath}/${prefix}.atac.archr.umap_tss_score.${genome}.png'
    String umap_frip_plot = '${plots_filepath}/${prefix}.atac.archr.umap_frip.${genome}.png'
    String umap_doublets = '${plots_filepath}/${prefix}.atac.archr.umap_doublets.${genome}.png'
    String heatmap_plot = '${plots_filepath}/${prefix}.atac.archr.heatmap.${genome}.png'

    #PDFs generated by ArchR - no longer retrieving these
    #String doublet_summary_plot = 'QualityControl/${prefix}/${prefix}-Doublet-Summary.pdf'
    #String fragment_size_dist_plot = 'QualityControl/${prefix}/${prefix}-Fragment_Size_Distribution.pdf'
    #String TSS_uniq_frags_plot = 'QualityControl/${prefix}/${prefix}-TSS_by_Unique_Frags.pdf'

    #Other filepaths
    String arrow_file = '${prefix}.arrow'
    String raw_archr_rds = '${prefix}.atac.archr.raw_project.${genome}.rds'
    String filtered_archr_rds = '${prefix}.atac.archr.filtered_project.${genome}.rds'
    String raw_archr_h5 = '${prefix}.atac.archr.raw_matrix.${genome}.h5'
    String filtered_archr_h5 = '${prefix}.atac.archr.filtered_matrix.${genome}.h5'
    String barcode_metadata = '${prefix}.atac.archr.barcode_metadata.${genome}.tsv'
    String plots_zip_dir = '${plots_filepath}.zip'
    #String papermill_log_filename = 'papermill.logfile.txt'
    #numbers to output from archr
    String archr_nums = 'archr_nums.txt'

    # re-add -p archr_nums ${archr_nums} 
    # when everything else is working
    command {

        
        papermill $(which archr_notebook.ipynb) ${output_filename} \
        -p atac_frag ${atac_frag} \
        -p genome ${genome} \
        -p peak_set ${peak_set} \
        -p papermill ${papermill} \
        -p min_tss ${min_tss} \
        -p min_frags ${min_frags} \
        -p add_tile_mat ${add_tile_mat} \
        -p add_gene_score_mat ${add_gene_score_mat} \
        -p find_doublets ${find_doublets} \
        -p doublet_k ${doublet_k} \
        -p doublet_knn_method ${doublet_knn_method} \
        -p lsi_method ${lsi_method} \
        -p copy_arrow_files ${copy_arrow_files} \
        -p iter_LSI_matrix ${iter_LSI_matrix} \
        -p threads ${threads} \
        -p prefix ${prefix} \
        -p marker_features_test ${marker_features_test} \
        -p heatmap_transpose ${heatmap_transpose} \
        -p heatmap_label_n ${heatmap_label_n} \
        -p heatmap_cutoff ${heatmap_cutoff}
    
        echo ${min_frags} >> ${archr_nums}
        echo ${min_tss} >> ${archr_nums}
    
    }

    output {
        File notebook_output = output_filename
        File notebook_log = log_filename
        File archr_barcode_metadata = barcode_metadata
        #File papermill_log = papermill_log_filename

        File? archr_raw_tss_by_uniq_frags_plot = raw_tss_by_uniq_frags_plot
        File? archr_raw_frag_size_dist_plot = raw_frag_size_dist_plot
        File? archr_filtered_tss_by_uniq_frags_plot = filtered_tss_by_uniq_frags_plot
        File? archr_filtered_frag_size_dist_plot = filtered_frag_size_dist_plot
        File? archr_umap_cluster_plot = umap_cluster_plot
        File? archr_umap_num_frags_plot = umap_num_frags_plot
        File? archr_umap_tss_score_plot = umap_tss_score_plot
        File? archr_umap_frip_plot = umap_frip_plot
        File? archr_umap_doublets = umap_doublets
        File? archr_heatmap_plot = heatmap_plot

        File? plots_zip = plots_zip_dir
        File? archr_arrow = arrow_file
        File? archr_raw_obj = raw_archr_rds
        File? archr_filtered_obj = filtered_archr_rds
        File? archr_raw_matrix = raw_archr_h5
        File? archr_filtered_matrix = filtered_archr_h5

        #output file of relevant numbers from archr
        File archr_numbers = archr_nums
    }

    runtime {
        cpu : 4
        memory : mem_gb+'G'
        docker : docker_image
        disks : 'local-disk ${disk_gb} ${disk_type}'
        maxRetries : 1
        bootDiskSizeGb: 50
        memory_retry_multiplier: 2
    }

    parameter_meta {
        atac_frag: {
            description: 'ATAC fragment file',
            help: 'ATAC fragments in .bedpe.gz format',
            example: 'atac.bedpe.gz'
        }

        papermill: {
            description: 'Boolean papermill flag',
            help: 'Flag to notebook run in papermill mode',
            example: 'TRUE'
        }

        genome: {
            description: 'Reference name',
            help: 'The name genome reference used to align.',
            examples: ['hg38', 'mm10', 'hg19', 'mm9'],
        }

        output_filename: {
            description: 'Output jupyter notebook name',
            help: 'The name assigned to output jupyter notebook',
            examples: 'output.ipynb',
        }

        docker_image: {
            description: 'Docker image.',
            help: 'Docker image for preprocessing step.' ,
            example: ['put link to gcr or dockerhub']
        }

        min_tss: {
            description: 'Min TSS enrichment score',
            help: 'The minimum numeric transcription start site (TSS) enrichment score required for a cell to pass filtering',
            example: 4
        }

        min_frags: {
            description: 'Min number of mapped fragments',
            help: 'The minimum number of mapped ATAC-seq fragments required per cell to pass filtering for use',
            example: 1000
        }

        add_tile_mat: {
            description: 'Compute Tile Matrix if TRUE',
            help: 'A boolean value indicating whether to add a "Tile Matrix" to each ArrowFile.',
            example: 'TRUE'
        }

        add_gene_score_mat: {
            description: 'Compute Gene Score Matrix if TRUE',
            help: 'A boolean value indicating whether to add a Gene-Score Matrix to each ArrowFile.',
            example: 'TRUE'
        }

        doublet_k: {
            description: 'Number of simulated neighbors to be considered doublet',
            help: 'The number of cells neighboring a simulated doublet to be considered as putative doublets.',
            example: 10
        }

        doublet_knn_method: {
            description: 'Embedding method for doublet detection',
            help: 'Refers to the embedding to use for nearest neighbor search.',
            examples: ['UMAP','LSI']
        }

        lsi_method: {
            description: 'Order of operations of TF-IDF normalization (see ArchR manual)',
            help: 'A number or string indicating the order of operations in the TF-IDF normalization. Possible values are: 1 or "tf-logidf", 2 or "log(tf-idf)", and 3 or "logtf-logidf"',
            examples: [1,2,3]
        }

        copy_arrow_files: {
            description: 'Makes a copy of arrow files',
            help: 'Save a copy of arrow files in the ArchR project (recommended)',
            example: 'TRUE'
        }

        iter_LSI_matrix: {
            description: 'Data matrix to retrieve',
            help: 'The name of the data matrix to retrieve from the ArrowFiles associated with the ArchRProject.',
            examples: ['PeakMatrix','TileMatrix']
        }

        threads: {
            description: 'Number of threads to run ArchR',
            help: 'Set threads to run ArchR. For now, recommended to run on single (1) thread.',
            example: 1
        }

        prefix: {
            description: 'Project name',
            help: 'String used to name your project and associated file names',
            example: "shareseq"
        }

        marker_features_test: {
            description: 'Pairwise test method',
            help: 'The name of the pairwise test method to use in comparing cell groupings to the null cell grouping during marker feature identification.',
            examples: ['wilcoxon', 'ttest', 'binomial']
        }

        heatmap_transpose: {
            description: 'Boolean to transpose heatmap',
            help: 'Plots genes on columns if TRUE',
            example: 'TRUE'
        }

        heatmap_label_n: {
            description: 'Top n genes to label',
            help: 'Extracts the top n upregulated genes in cluster to label on heatmap',
            example: 5
        }

        heatmap_cutoff: {
            description: 'Cut-off applied to genes in heatmap',
            help: 'Cut-off has to be specified in string format',
            example: 'FDR <= 0.01 & Log2FC >= 0.5'
        }
    }
}
