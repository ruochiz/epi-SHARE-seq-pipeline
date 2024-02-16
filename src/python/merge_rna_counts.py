#!/usr/bin/env python3
# coding: utf-8
"""
Merge RNA count matrices
"""

import argparse
import gzip
import h5py
import numpy as np
import os.path
import tarfile
from collections import defaultdict
from scipy.sparse import csc_matrix

def parse_arguments():
    parser = argparse.ArgumentParser(description="Generate a merged h5 count matrix of genes x barcodes")
    parser.add_argument("prefix", help="Prefix for naming output files")
    parser.add_argument("merged_h5_file", help="File name for output merged h5 file")
    parser.add_argument("dataset_barcodes_file", help="File name for output dataset barcodes tsv file")
    parser.add_argument("--tar_files", nargs="*", help="File names for tar archives, one per matrix to be merged. Each must contain matrix.mtx, features.tsv, and barcodes.tsv files")
    parser.add_argument("--subpools", nargs="*", help="Cellular sub-pool names, one per matrix to be merged")
    parser.add_argument("--datasets", nargs="*", help="Dataset names, one per matrix to be merged")
    parser.add_argument("--ensembl", help="Flag for outputting gene names in ENSEMBL form, rather than gene id", action="store_true")
    return parser.parse_args()


def get_split_lines(file_name, delimiter, skip=0):
    """
    Read file contents and yield generator with line entries
    """
    opener = gzip.open if file_name.endswith('.gz') else open
    with opener(file_name, "rt") as f:
        for i in range(skip):
            next(f)
        for line in f:
            yield line.rstrip().split(sep=delimiter)


def rename_duplicates(duplicate_list):
    """Rename duplicate entries as entry, entry.1, entry.2, etc."""
    seen = defaultdict(int)
    renamed_list = []
    
    for entry in duplicate_list:
        renamed_list.append(f"{entry}.{seen[entry]}" if entry in seen else entry)
        seen[entry] += 1
        
    return renamed_list

            
def get_merged_data(tar_files, subpools, datasets, ensembl):
    """
    Takes in paths to tar files (one per count matrix to be merged)
    containing barcodes.tsv, features.tsv, and matrix.mtx output files from STARsolo. 
    Merges matrices by translating individual mtx file indices to a master set of indices. 
    Outputs merged CSC matrix, barcode list, and gene list. 
    If the same barcode(+subpool) is present in multiple tar files, its counts will be summed by default.
    However, if concat==True, each occurrence will be preserved in its own column.
    Genes will be outputted as ENSEMBL IDs if ensembl==True, and as gene symbols otherwise.
    """
    barcode_mappings = []
    gene_mappings = []
    ensembl_to_gene = {}
    dataset_barcodes = {}
    
    # get barcode mappings and gene mappings
    for i in range(len(tar_files)):
        tar = tarfile.open(tar_files[i], mode="r")
        tar.extract("barcodes.tsv.gz")
        tar.extract("features.tsv.gz")
        
        # read barcodes file
        barcodes = get_split_lines("barcodes.tsv.gz", delimiter="\t")
        # get mapping of barcode to column index; {barcode:col_idx}
        # append subpool name with underscore if supplied
        if subpools:
            barcode_mapping = {line[0] + "_" + subpools[i]:idx for idx, line in enumerate(barcodes)}
        else:
            basename = os.path.basename(tar_files[i])
            barcode_mapping = {line[0] + "_" + basename:idx for idx, line in enumerate(barcodes)}
        
        for barcode in barcode_mapping.keys():
            dataset_barcodes[barcode] = datasets[i]
   
        barcode_mappings.append(barcode_mapping)
        
        # read features file
        features = get_split_lines("features.tsv.gz", delimiter="\t")              
        # get mapping of gene to row index; {gene:row_idx}
        ensembl_dict = {line[0]:line[1] for line in features}
        ensembl_to_gene.update(ensembl_dict)
        gene_mapping = {key:idx for idx, key in enumerate(ensembl_dict.keys())}
        gene_mappings.append(gene_mapping)
        
        tar.close()
    
    # get list of unique barcodes and genes
    barcode_list = list({k for d in barcode_mappings for k in d.keys()})
    gene_list = list({k for d in gene_mappings for k in d.keys()})   
    
    # assign column indices for master list of barcodes and row indices for master list of genes
    merged_barcode_mapping = {barcode:idx for idx, barcode in enumerate(barcode_list)}
    merged_gene_mapping = {gene:idx for idx, gene in enumerate(gene_list)}
    
    n_row = len(gene_list)
    n_col = len(barcode_list) 
    merged_matrix = csc_matrix((n_row,n_col))
    
    # get concordances between indices in individual gene/barcode mappings and indices in merged mappings;
    # create csc matrix using counts from mtx file and add to merged matrix
    for i in range(len(tar_files)):
        barcode_mappings[i] = {idx:merged_barcode_mapping[barcode] for barcode, idx in barcode_mappings[i].items()}
        gene_mappings[i] = {idx:merged_gene_mapping[gene] for gene, idx in gene_mappings[i].items()}
        
        count_mapping = {}
        
        tar = tarfile.open(tar_files[i], mode="r")
        tar.extract("matrix.mtx.gz")
        matrix = get_split_lines("matrix.mtx.gz", delimiter=" ", skip=3)
        
        for entry in matrix:
            # subtract 1 from indices to convert to zero-based indexing
            row_ind = gene_mappings[i][int(entry[0])-1]
            col_ind = barcode_mappings[i][int(entry[1])-1]
            count = int(entry[2])
            count_mapping[(row_ind,col_ind)] = count
                    
        merged_matrix += csc_matrix((list(count_mapping.values()), zip(*count_mapping.keys())), shape=(n_row,n_col))
        
        tar.close()
    
    # if gene names to be outputted, convert and rename duplicate genes
    if not ensembl:
        gene_list = rename_duplicates([ensembl_to_gene[ensembl_id] for ensembl_id in gene_list])
    
    return(merged_matrix, barcode_list, gene_list, ensembl_to_gene, dataset_barcodes)

        
def write_h5(prefix, count_matrix, barcode_list, gene_list, merged_h5_file):
    h5_file = h5py.File(merged_h5_file, "w")

    g = h5_file.create_group("group")
    g.create_dataset("barcodes", data=barcode_list)
    g.create_dataset("data", data=count_matrix.data)
    g.create_dataset("gene_names", data=gene_list)
    g.create_dataset("genes", data=gene_list)
    g.create_dataset("indices", data=count_matrix.indices)
    g.create_dataset("indptr", data=count_matrix.indptr)
    g.create_dataset("shape", data=count_matrix.shape)

    h5_file.close()   

    
def write_starsolo_outputs(prefix, count_matrix, barcode_list, ensembl_to_gene):
    with gzip.open(prefix + ".features.tsv.gz", "wt") as f:
        for ensembl, gene in ensembl_to_gene.items(): 
            f.write("%s\t%s\n" % (ensembl, gene))
    
    with gzip.open(prefix + ".barcodes.tsv.gz", "wt") as f:
        for barcode in barcode_list:
            f.write("%s\n" % barcode)
            
    row, col = count_matrix.nonzero()
    with gzip.open(prefix + ".matrix.mtx.gz", "wt") as f:
        # write header lines
        f.write("%%MatrixMarket matrix coordinate integer general\n%\n")
        f.write("%s %s %s\n" % (count_matrix.shape[0], count_matrix.shape[1], count_matrix.nnz))
        for triple in zip(row, col, count_matrix.data):
            f.write("%s %s %s\n" % triple)


def write_dataset_barcodes(prefix, dataset_barcodes, dataset_barcodes_file):
    with open(dataset_barcodes_file, "w") as f:
        f.write("barcode\tdataset\n")
        for barcode, dataset in dataset_barcodes.items():
            f.write(barcode + "\t" + dataset + "\n")	 

            
def main():
    # get arguments
    args = parse_arguments()
    prefix = getattr(args, "prefix")
    merged_h5_file = getattr(args, "merged_h5_file")
    dataset_barcodes_file = getattr(args, "dataset_barcodes_file")
    tar_files = getattr(args, "tar_files")
    subpools = getattr(args, "subpools")
    datasets = getattr(args, "datasets")
    ensembl = getattr(args, "ensembl")
    
    # get merged count matrix, barcode list, and gene list from input tars
    count_matrix, barcode_list, gene_list, ensembl_to_gene, dataset_barcodes = get_merged_data(tar_files, subpools, datasets, ensembl)
    
    # write merged data to h5 file
    write_h5(prefix, count_matrix, barcode_list, gene_list, merged_h5_file)
    
    # write merged data to matrix.mtx, features.tsv, and barcodes.tsv files
    write_starsolo_outputs(prefix, count_matrix, barcode_list, ensembl_to_gene)

    # write dataset barcode tsv
    write_dataset_barcodes(prefix, dataset_barcodes, dataset_barcodes_file)

if __name__ == "__main__":
    main()

