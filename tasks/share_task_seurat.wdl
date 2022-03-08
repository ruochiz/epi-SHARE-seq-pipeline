version 1.0

task seurat {
    meta {
        version: 'v0.1'
        author: 'Kevin Dong (kdong@broadinstitute.org) at Broad Institute of MIT and Harvard'
        description: 'Broad Institute of MIT and Harvard SHARE-Seq pipeline: run seurat task'
    }

    input {
        #This tasks takes in an RNA matrix file, processes using Seurat and creates plots
        
        File rna_matrix = "rna.h5" 
        String genome = "hg38" 

        Int min_features = 200 
        Float percent_MT = 5.0
        Int min_cells = 3 

        String normalization_method = "LogNormalize"
        Float normalization_scale_factor = 10000

        String variable_features_method = "vst"
        Int variable_features_num = 2000

        Int dim_loadings_dim = 2 

        Int jackstraw_replicates = 100
        Int jackstraw_score_dim = 20 
        Int jackstraw_plot_dim = 15 

        Int heatmap_dim = 1 
        Int heatmap_cells = 500 
        String heatmap_balanced = "TRUE" 

        Int umap_dim = 10 
        Float umap_resolution = 0.5 

        String prefix = "prefix" 
        
        String papermill = "TRUE" 
        String output_filename = "output.ipynb"
        String docker_image = ""
        Int mem_gb = 16
    }

    command {
        
        papermill $(which seurat_notebook.ipynb) ${output_filename} \
        -p rna_matrix ${rna_matrix} \
        -p genome ${genome} \
        -p min_features ${min_features} \
        -p percent_MT ${percent_MT} \
        -p min_cells ${min_cells} \
        -p normalization_method ${normalization_method} \
        -p normalization_scale_factor ${normalization_scale_factor} \
        -p variable_features_method ${variable_features_method} \
        -p variable_features_num ${variable_features_num} \
        -p dim_loadings_dim ${dim_loadings_dim} \
        -p jackstraw_replicates ${jackstraw_replicates} \
        -p jackstraw_score_dim ${jackstraw_score_dim} \
        -p jackstraw_plot_dim ${jackstraw_plot_dim} \
        -p heatmap_dim ${heatmap_dim} \
        -p heatmap_cells ${heatmap_cells} \
        -p heatmap_balanced ${heatmap_balanced} \
        -p umap_dim ${umap_dim} \
        -p umap_resolution ${umap_resolution} \
        -p prefix ${prefix} \
        -p papermill ${papermill}
    }

    output {
        File notebook_output = output_filename
        File seurat_violin_plot = glob("plots/*violin*.png")[0]
        File seurat_mitochondria_qc_plot = glob("plots/*mitochondria*.png")[0]
        File seurat_features_plot = glob("plots/*features*.png")[0]
        File seurat_PCA_dim_loadings_plot = glob("plots/*dimLoadings*.png")[0]
        File seurat_PCA_plot = glob("plots/*pca*.png")[0]
        File seurat_heatmap_plot = glob("plots/*heatmap*.png")[0]
        File seurat_jackstraw_plot = glob("plots/*jackstraw*.png")[0]
        File seurat_elbow_plot = glob("plots/*elbow*.png")[0]
        File seurat_umap_plot = glob("plots/*umap*.png")[0]
        File seurat_obj = glob("*.rds")[0]
        File plots_zip = "plots.zip"
    }

    runtime {
        cpu : 4
        memory : mem_gb+'G'
        docker : docker_image
    }
    
    parameter_meta {
        rna_matrix: {
            description: 'RNA matrix h5',
            help: 'RNA counts in matrix .h5 format',
            example: 'rna.h5'
        }
        
        papermill: {
            description: 'Boolean papermill flag',
            help: 'Flag to notebook run in papermill mode',
            example: 'TRUE'
        }
        
        genome: {
            description: 'Reference name',
            help: 'The name genome reference used to align.',
            examples: ['hg38', 'mm10', 'hg19', 'mm9']
        }
        
        min_features: {
            description: 'Minimum num of features',
            help: 'Seurat QC for number (integer) of min features',
            example: 200
        }
        
        percent_MT: {
            description: 'Max percentage of MT reads in cell',
            help: 'Seurat QC for max % (float) of mt',
            example: 5.0
        }
        
        min_cells: {
            description: 'Feature to be reported if it is in atleast min number of cells',
            help: 'Seurat QC for min number of cells',
            example: 3
        }
        
        normalization_method: {
            description: 'Normalization method used in Seurat',
            help: 'Seurat normalization method used in Seurat::NormalizeData()',
            examples: ["LogNormalize","CLR","RC"]
        }
        
        normalization_scale_factor: {
            description: 'Scaling factor used in Seurat normalization',
            help: 'Scaling factor parameter used in Seurat::NormalizeData()',
            example: 10000
        }
        
        variable_features_method: {
            description: 'Method used to select variable features',
            help: 'Parameter used in Seurat::FindVariableFeatures()',
            example: "vst"
        }
        
        variable_features_num: {
            description: 'Number of variable features used to find',
            help: 'Parameter used in Seurat::FindVariableFeatures()',
            example: 2000
        }
        
        dim_loadings_dim: {
            description: 'Number of dimensions to display in PCA',
            help: 'Parameter used in Seurat::VizDimLoadings()',
            example: 2
        }
        
        jackstraw_replicates: {
            description: 'Number of replicate samplings to perform',
            help: 'Parameter used in Seurat::JackStraw()',
            example: 100
        }
        
        jackstraw_score_dim: {
            description: 'Number of dimensions to examine in JackStraw Plot',
            help: 'Parameter used in Seurat::ScoreJackStraw(), in default case, 1:20',
            example: 20
        }
        
        jackstraw_plot_dim: {
            description: 'Number of dimensions to plot in JackStraw Plot',
            help: 'Parameter used in Seurat::JackStrawPlot(), in default case, 1:15',
            example: 15
        }
        
        heatmap_dim: {
            description: 'Number of dimensions to use for heatmap',
            help: 'Parameter used in Seurat::DimHeatmap()',
            example: 1
        }
        
        heatmap_cells: {
            description: 'A list of cells to plot. If numeric, just plots the top cells.',
            help: 'Parameter used in Seurat::DimHeatmap()',
            example: 500
        }
        
        heatmap_balanced: {
            description: 'Plot an equal number of genes with both + and - scores.',
            help: 'Parameter used in Seurat::DimHeatmap()',
            example: "TRUE"
        }
        
        umap_dim: {
            description: 'Dimensions (number of PCs) used to create umap, in the default case, 1:umap_dim = 1:10',
            help: 'Parameter used in Seurat::FindNeighbors and Seurat::RunUMAP()',
            example: 10
        }
        
        umap_resolution: {
            description: 'Value of the resolution parameter, use a value below 1.0 if you want to obtain a smaller number of communities.',
            help: 'Parameter used in Seurat::FindClusters()',
            example: 0.5
        }
        
        papermill: {
            description: 'Boolean papermill flag',
            help: 'Flag to notebook run in papermill mode',
            example: 'TRUE'
        }
        
        prefix: {
            description: 'Project name',
            help: 'String used to name your project and associated file names',
            example: "shareseq"
        }
                
        output_filename: {
            description: 'Output jupyter notebook name',
            help: 'The name assigned to output jupyter notebook',
            examples: 'output.ipynb'
        }
        
        docker_image: {
            description: 'Docker image.',
            help: 'Docker image for preprocessing step.', 
            example: ['put link to gcr or dockerhub']
        }
    }
}