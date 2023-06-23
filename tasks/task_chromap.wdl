version 1.0

# TASK
# SHARE-atac-chromap

task atac_align_chromap {
    meta {
        version: 'v0.1'
        author: 'Eugenio Mattei (emattei@broadinstitute.org) at Broad Institute of MIT and Harvard'
        description: 'Broad Institute of MIT and Harvard SHARE-Seq pipeline: align ATAC task using chromap'
    }

    input {
        # This task takes in input the preprocessed ATAC fastqs and align them to the genome.
        Array[File] fastq_R1
        Array[File] fastq_R2
        Array[File] fastq_barcode
        File reference_fasta
        File? barcode_inclusion_list
        File? barcode_translation_dict

        Int? multimappers = 4
        Int? bc-error-threshold = 2
        Float? bc-probability-threshold = 0.9
        String? read_format

        String? subpool = "none"
        String genome_name          # GRCh38, mm10
        String prefix = "sample-share"

        Int? cpus = 16
        Float? disk_factor = 8.0
        Float? memory_factor = 0.15
        String? docker_image = "us.gcr.io/buenrostro-share-seq/share_task_bowtie2"
    }

    # Determine the size of the input
    Float input_file_size_gb = size(fastq_R1, "G") + size(fastq_R2, "G")

    # Determining memory size base on the size of the input files.
    Float mem_gb = 24.0 + size(genome_index_tar, "G") + memory_factor * input_file_size_gb

    # Determining disk size base on the size of the input files.
    Int disk_gb = round(40.0 + disk_factor * input_file_size_gb)

    # Determining disk type base on the size of disk.
    String disk_type = if disk_gb > 375 then "SSD" else "LOCAL"

    # Define the output names
    String fragments = '${prefix}.atac.filter.fragments.${genome_name}.tsv'
    String barcode_log = "${prefix}.atac.align.k${multimappers}.${genome_name}.barcode.log.txt"
    String alignment_log = "${prefix}.atac.align.k${multimappers}.${genome_name}.log.txt"

    String monitor_log = "atac_align_monitor.log"

    command <<<
        set -e

        bash $(which monitor_script.sh) > ~{monitor_log} 2>&1 &

        # Create index
        mkdir chromap_index
        chromap -i -r ~{reference_fasta} -o chromap_index/index

        # [r1|r2|bc]:start:end:strand
        # --read-format bc:0:15,r1:16:-1
        # The start and end are inclusive and -1 means the end of the read. User may use multiple fields to specify non-consecutive segments, e.g. bc:0:15,bc:32:-1.
        # The strand is presented by '+' and '-' symbol, if '-' the barcode will be reverse-complemented after extraction
~{true='--use-allele-specific-annotations' false='' use_allele_specific_annotations}
        chromap -x chromap_index/index \
                --trim-adapters \
                --remove-pcr-duplicates \
                --remove-pcr-duplicates-at-cell-level \
                -l 2000 \
                --Tn5-shift \
                --low-mem \
                --BED \
                ~{"--bc-error-threshold " + bc-error-threshold} \
                ~{"--bc-probability-threshold " + bc-probability-threshold} \
                ~{"--read_format " + read_format} \
                --drop-repetitive-reads 4 \
                -x chromap_index/index \
                -r ~{reference_fasta} \
                -q 0 \
                -t ~{cpus} \
                -1 ~{sep="," fastq_R1} \
                -2 ~{sep="," fastq_R2} \
                -b ~{sep="," fastq_barcode} \
                ~{"--barcode-whitelist" + barcode_inclusion_list} \
                ~{"--barcode-translate " + barcode_translation_dict} \
                -o ~{fragments} \
                --summary ~{barcode_log}
        
        if [[ ~{subpool} != "none" ]]; then
            awk -v OFS="\t" -v subpool=~{subpool} '{$4=$4"_"$subpool; print $0}' ~{fragments} > temp
            mv temp ~{fragments}
        fi

        pigz -p ~{cpus} ~{fragments}
        tabix --zero-based --preset bed ~{fragments}.gz

    >>>

    output {
        File atac_fragments = "~{fragments}.gz"
        File atac_fragments_index = "~{fragments}.gz.tbi"
        File atac_align_barcode_statistics = barcode_log
    }

    runtime {
        cpu: cpus
        docker: "${docker_image}"
        singularity: "docker://${docker_image}"
        disks: "local-disk ${disk_gb} ${disk_type}"
        memory: "${mem_gb} GB"
    }

    parameter_meta {
        fastq_R1: {
                description: 'Read1 fastq.',
                help: 'Processed fastq for read1.',
                example: 'input.atac.R1.fq.gz',
            }
        fastq_R2: {
                description: 'Read2 fastq.',
                help: 'Processed fastq for read2.',
                example: 'input.atac.R2.fq.gz'
            }
        multimappers: {
                    description: 'Specifiy the numbers of multimappers allowed.',
                    help: 'This is the integer that will be passed to the -k parameter of bowtie2',
                    example: [5]
            }
        cpus: {
                description: 'Number of cpus.',
                help: 'Set the number of cpus used by bowtie2',
                default: 16
            }
        disk_factor: {
                description: 'Multiplication factor to determine disk required for task align.',
                help: 'This factor will be multiplied to the size of FASTQs to determine required disk of instance (GCP/AWS) or job (HPCs).',
                default: 8.0
            }
        memory_factor: {
                description: 'Multiplication factor to determine memory required for task align.',
                help: 'This factor will be multiplied to the size of FASTQs to determine required memory of instance (GCP/AWS) or job (HPCs).',
                default: 0.15
            }
        genome_name: {
                description: 'Reference name.',
                help: 'The name of the reference genome used by the aligner. This is appended to the output file name.',
                examples: ['GRCh38', 'mm10']
            }
        prefix: {
                description: 'Prefix for output files.',
                help: 'Prefix that will be used to name the output files',
                examples: 'my-experiment'
            }
        docker_image: {
                description: 'Docker image.',
                help: 'Docker image for the alignment step.',
                example: ["us.gcr.io/buenrostro-share-seq/share_task_bowtie2"]
            }
    }
}