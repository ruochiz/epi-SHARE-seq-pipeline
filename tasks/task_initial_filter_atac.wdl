version 1.0

# TASK
# initial-filter-atac




task atac_initial_filter {
    meta {
        version: 'v0.1'
        author: 'Eugenio Mattei (emattei@broadinstitute.org) at Broad Institute of MIT and Harvard'
        description: 'Broad Institute of MIT and Harvard SHARE-Seq pipeline: Initial filter ATAC'
    }

    input {
        # This task takes in input the aligned bam file and rmeove the low quality reads, the extra chromosomes, marks
        # the duplicats, and convert to a bedpe file.
        File? bam
        File? bam_index
        Int? multimappers = 1
        Int? minimum_fragments_cutoff = 10
        String? barcode_tag_fragments = "CB"

        String genome_name
        String? prefix = "sample"

        ## Runtime
        Int? cpus = 16
        Float? disk_factor = 10.0
        Float? memory_factor = 0.15
        String docker_image = "us.gcr.io/buenrostro-share-seq/share_task_filter_atac"
        String singularity_image = "docker://us.gcr.io/buenrostro-share-seq/share_task_filter_atac"
    }

    # Determine the size of the input
    Float input_file_size_gb = size(bam, "G")

    # Determining memory size base on the size of the input files.
    Float mem_gb = 32.0 + memory_factor * input_file_size_gb

    # Determining disk size base on the size of the input files.
    Int disk_gb = round(20.0 + disk_factor * input_file_size_gb)

    # Determining disk type base on the size of disk.
    String disk_type = if disk_gb > 375 then "SSD" else "LOCAL"

    # Determining memory for samtools.
    Int samtools_memory_gb = floor(0.9 * mem_gb) # Samtools has overheads so reducing the memory to 80% of the total.

    # Number of threads to beable to use 4GB of memory per thread seems to be the fastest way
    Int samtools_threads_ = floor(samtools_memory_gb / 4)
    Int samtools_threads =  if samtools_threads_ == 0 then 1 else samtools_threads_

    Int sambamba_threads = floor(cpus/2)

    # This might become a problem if less then or 4 threads are passed in input.
    # Minimum should be eight.
    Int parallel_threads = 4
    Int samtools_view_threads = floor((cpus-4)/4)

    # Now that we know how many threads we can use to assure 4GB of memory per thread
    # we assign any remaining memory to the threads.
    Int samtools_memory_per_thread_ = floor(samtools_memory_gb * 1024 / samtools_threads) # Computing the memory per thread for samtools in MB.
    Int samtools_memory_per_thread = if samtools_memory_per_thread_ < 768 then 768 else samtools_memory_per_thread_

    #String filtering_params = if multimappers == 0 then "-q ${mapq_threshold} -F 1804" else "-F 524"

    String non_mito_bam = "${prefix}.atac.align.k${multimappers}.${genome_name}.nonmito.sorted.bam"

    String tmp_filtered_bam = '${prefix}.filtered.tmp.bam'
    String tmp_fixmate_bam = '${prefix}.filtered.fixmate.tmp.bam'

    String monitor_log = "atac_initial_filter_monitor.log"

    command<<<
        set -e

        # I am not writing to a file anymore because Google keeps track of it automatically.
        bash $(which monitor_script.sh) 1>&2 &


        # I need to do this because the bam and bai need to be in the same folder but WDL doesn't allow you to
        # co-localize them in the same path.
        ln -s ~{bam} in.bam
        ln -s ~{bam_index} in.bam.bai

        # "{prefix}.mito.bulk-metrics.tsv"
        # "{prefix}.mito.bc-metrics.tsv"

        echo '------ START: Filtering out mito reads ------' 1>&2
        # The script removes the mithocondrial reads and creates two log file with bulk and barcode statistics.
        time python3 $(which filter_mito_reads.py) -o ~{non_mito_bam} -p ~{cpus} --cutoff ~{minimum_fragments_cutoff} --prefix ~{prefix} --bc_tag ~{barcode_tag_fragments} in.bam

        sambamba index -t ~{cpus} ~{non_mito_bam}

        # Keep only assembled chromosomes
        chrs=$(samtools view -H ~{non_mito_bam}| \
            grep chr | \
            cut -f2 | \
            sed 's/SN://g' | \
            awk '{if(length($0)<6)print}')

        # =============================
        # Remove  unmapped, mate unmapped
        # not primary alignment, reads failing platform
        # Only keep properly paired reads
        # Obtain name sorted BAM file
        # =============================
        echo '------ START: Filter bam -F 524 -f 2 and sort ------' 1>&2
        time sambamba view -h -t ~{sambamba_threads} --num-filter 2/524 -f bam ~{non_mito_bam} $(echo ${chrs}) | \
        sambamba sort -t ~{cpus} -m ~{samtools_memory_gb}G -n -o ~{tmp_filtered_bam} /dev/stdin

        # Assign multimappers if necessary
        if [ ~{multimappers} -le 1 ]; then
            echo '------ START: Fixmate step ------' 1>&2
            time sambamba view -t ~{cpus} -h -f sam ~{tmp_filtered_bam}  | samtools fixmate -@ ~{cpus} -r /dev/stdin ~{tmp_fixmate_bam}
        else
            echo '------ START: Assinging multimappers ------' 1>&2
            time sambamba view -t ~{cpus} -h -f sam ~{tmp_filtered_bam} | \
            python3 $(which assign_multimappers.py) -k ~{multimappers} --paired-end | sambamba view -t ~{cpus} -f sam /dev/stdin | samtools fixmate -@ ~{cpus} -r /dev/stdin ~{tmp_fixmate_bam}
        fi

        # Cleaning up bams we don't need anymore
        rm ~{tmp_filtered_bam}
        rm ~{non_mito_bam}

        # Split into chromosomes to speed up the marking of duplicates.
        # get list of chromosomes from the bam file
        chromosomes=$(samtools idxstats ~{tmp_fixmate_bam} | cut -f1 | grep -v '*')

        input_split_bam=~{tmp_fixmate_bam}

        # parallel tool execution of samtools view for each chromosome
        # I am removing the -k option because the order is not going to be maintained in the following steps.
        # Saving the order of chromosomes for when I am going to merge.
        printf "%s\n" ${chromosomes} | parallel -j ~{parallel_threads} "samtools view -@ ~{samtools_view_threads} -b ${input_split_bam} > {}.bam"

    >>>

    output {
        Array[File] atac_initial_filter_bams_to_dedup = glob("chr*.bam")
        File? atac_initial_filter_monitor_log = monitor_log
        File? atac_initial_filter_mito_metrics_bulk = "~{prefix}.mito.bulk-metrics.tsv"
        File? atac_initial_filter_mito_metrics_barcode = "~{prefix}.mito.bc-metrics.tsv"
    }

    runtime {
        cpu: cpus
        memory: "${mem_gb} GB"
        disks: "local-disk ${disk_gb} ${disk_type}"
        docker: "${docker_image}"
        singularity: "${singularity_image}"
        maxRetries: 1
    }

    parameter_meta {
        bam: {
                description: 'bam file',
                help: 'Aligned reads in bam format',
                example: 'aligned.hg38.bam'
            }
        bam_index: {
            description: 'bai file',
            help: 'Index for the aligned reads in bam format',
            example: 'aligned.hg38.bam.bai'
            }
        barcode_tag_fragments: {
            description: 'tag containing the barcode',
            help: 'Which tag inside the bam file contains the cell barcode.',
            examples: ['CB','XC']
            }
        genome_name: {
                description: 'Reference name.',
                help: 'The name of the reference genome used. This is appended to the output file name.',
                examples: ['GRCh38', 'mm10']
            }
        prefix: {
                description: 'Prefix for output files.',
                help: 'Prefix that will be used to name the output files',
                examples: 'my-experiment'
            }
        multimappers: {
                    description: 'Specifiy the numbers of multimappers allowed.',
                    help: 'Number of multimppares that have been passed to bowtie2 during alignment',
                    example: [5]
            }
        cpus: {
                description: 'Number of cpus',
                help: 'Set the number of cpus.',
                examples: '16'
            }
        memory_factor: {
                description: 'Multiplication factor to determine memory required for task filter.',
                help: 'This factor will be multiplied to the size of bams to determine required memory of instance (GCP/AWS) or job (HPCs).',
                default: 0.15
            }
        disk_factor: {
                description: 'Multiplication factor to determine disk required for task filter.',
                help: 'This factor will be multiplied to the size of bams to determine required disk of instance (GCP/AWS) or job (HPCs).',
                default: 8.0
            }
        docker_image: {
                description: 'Docker image.',
                help: 'Docker image for the filtering step.',
                example: ["us.gcr.io/buenrostro-share-seq/share_task_filter"]
            }
        singularity_image: {
                description: 'Singularity image.',
                help: 'Singularity image for the filtering step.',
                example: ["docker://us.gcr.io/buenrostro-share-seq/share_task_filter"]
            }
    }


}
