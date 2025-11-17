"""
Aggregate evaluation results from Kaggle runs.
This script parses test results and creates CSV files with:
1. Detailed results per dataset and shot value
2. Summary averaged across datasets for each shot value
3. Overall summary statistics

Usage:
    python aggregate_kaggle_results.py --output-dir /kaggle/working/BiomedCoOp/output_eval \
                                       --results-dir /kaggle/working/BiomedCoOp/results
"""

import argparse
import os
import os.path as osp
import csv
import numpy as np
from collections import defaultdict
import re
from dassl.utils import check_isfile, listdir_nohidden


def compute_ci95(res):
    """Compute 95% confidence interval."""
    return 1.96 * np.std(res) / np.sqrt(len(res))


def parse_single_result(directory, end_signal="=> result"):
    """Parse results from a single evaluation directory."""
    print(f"Parsing: {directory}")
    subdirs = listdir_nohidden(directory, sort=True)
    
    accuracies = []
    metric_regex = re.compile(r"\* accuracy: ([\.\deE+-]+)%")
    
    for subdir in subdirs:
        fpath = osp.join(directory, subdir, "log.txt")
        if not check_isfile(fpath):
            continue
            
        good_to_go = False
        
        with open(fpath, "r") as f:
            lines = f.readlines()
            
            for line in lines:
                line = line.strip()
                
                if line == end_signal:
                    good_to_go = True
                
                if good_to_go:
                    match = metric_regex.search(line)
                    if match:
                        acc = float(match.group(1))
                        accuracies.append(acc)
                        print(f"  Found accuracy in {subdir}: {acc:.2f}%")
                        break
    
    if not accuracies:
        print(f"  Warning: No accuracies found in {directory}")
        return None, None
    
    mean_acc = np.mean(accuracies)
    std_acc = np.std(accuracies)
    
    print(f"  Mean: {mean_acc:.2f}% +- {std_acc:.2f}%")
    return mean_acc, std_acc


def main(args):
    # Configuration
    datasets = [
        "btmri", "busi", "chmnist", "covid", "ctkidney",
        "dermamnist", "kneexray", "kvasir", "lungcolon",
        "octmnist", "retina"
    ]
    
    shots_list = [1, 2, 4, 8, 16]
    
    trainer = "BiomedCoOp_BiomedCLIP"
    config_suffix = "nctx4_cscFalse_ctpend"
    
    # Create results directory
    os.makedirs(args.results_dir, exist_ok=True)
    
    # Store all results
    detailed_results = []
    results_by_shots = defaultdict(list)
    
    print("=" * 60)
    print("Starting result aggregation")
    print("=" * 60)
    print(f"Output directory: {args.output_dir}")
    print(f"Results directory: {args.results_dir}")
    print("")
    
    # Parse results for each dataset and shot value
    for dataset in datasets:
        print(f"\n{'=' * 60}")
        print(f"Processing dataset: {dataset.upper()}")
        print(f"{'=' * 60}")
        
        for k in shots_list:
            eval_dir = osp.join(
                args.output_dir,
                dataset,
                f"shots_{k}",
                trainer,
                config_suffix
            )
            
            if not osp.exists(eval_dir):
                print(f"Warning: Directory not found: {eval_dir}")
                continue
            
            print(f"\n{k}-shot evaluation:")
            mean_acc, std_acc = parse_single_result(eval_dir)
            
            if mean_acc is not None:
                detailed_results.append({
                    'dataset': dataset,
                    'shots': k,
                    'accuracy': mean_acc,
                    'std': std_acc
                })
                results_by_shots[k].append(mean_acc)
    
    # Save detailed results
    detailed_csv = osp.join(args.results_dir, "detailed_results.csv")
    print(f"\n{'=' * 60}")
    print(f"Saving detailed results to: {detailed_csv}")
    print(f"{'=' * 60}")
    
    with open(detailed_csv, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['dataset', 'shots', 'accuracy', 'std'])
        writer.writeheader()
        for result in detailed_results:
            writer.writerow(result)
            print(f"{result['dataset']:12s} | {result['shots']:2d}-shot | "
                  f"{result['accuracy']:6.2f}% +- {result['std']:5.2f}%")
    
    # Calculate and save summary by shots
    summary_csv = osp.join(args.results_dir, "summary_by_shots.csv")
    print(f"\n{'=' * 60}")
    print(f"Saving summary by shots to: {summary_csv}")
    print(f"{'=' * 60}")
    
    summary_results = []
    
    with open(summary_csv, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['shots', 'avg_accuracy', 'std_across_datasets', 'num_datasets'])
        writer.writeheader()
        
        for k in shots_list:
            if k in results_by_shots and results_by_shots[k]:
                accs = results_by_shots[k]
                avg_acc = np.mean(accs)
                std_acc = np.std(accs)
                num_datasets = len(accs)
                
                summary_results.append({
                    'shots': k,
                    'avg_accuracy': avg_acc,
                    'std_across_datasets': std_acc,
                    'num_datasets': num_datasets
                })
                
                writer.writerow({
                    'shots': k,
                    'avg_accuracy': f"{avg_acc:.2f}",
                    'std_across_datasets': f"{std_acc:.2f}",
                    'num_datasets': num_datasets
                })
                
                print(f"{k:2d}-shot | Avg: {avg_acc:6.2f}% +- {std_acc:5.2f}% | "
                      f"Datasets: {num_datasets}")
    
    # Create a pivot table for easy viewing
    pivot_csv = osp.join(args.results_dir, "pivot_table.csv")
    print(f"\n{'=' * 60}")
    print(f"Creating pivot table: {pivot_csv}")
    print(f"{'=' * 60}")
    
    # Create pivot table (datasets x shots)
    pivot_data = defaultdict(dict)
    for result in detailed_results:
        pivot_data[result['dataset']][result['shots']] = result['accuracy']
    
    with open(pivot_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        # Header
        writer.writerow(['Dataset'] + [f'{k}-shot' for k in shots_list])
        
        # Data rows
        for dataset in datasets:
            if dataset in pivot_data:
                row = [dataset]
                for k in shots_list:
                    if k in pivot_data[dataset]:
                        row.append(f"{pivot_data[dataset][k]:.2f}")
                    else:
                        row.append("N/A")
                writer.writerow(row)
        
        # Summary row
        summary_row = ['AVERAGE']
        for k in shots_list:
            if k in results_by_shots and results_by_shots[k]:
                avg = np.mean(results_by_shots[k])
                summary_row.append(f"{avg:.2f}")
            else:
                summary_row.append("N/A")
        writer.writerow(summary_row)
    
    # Display pivot table
    print("\nPivot Table:")
    print("-" * 80)
    with open(pivot_csv, 'r') as f:
        for line in f:
            print(line.strip())
    
    print(f"\n{'=' * 60}")
    print("Result aggregation completed!")
    print(f"{'=' * 60}")
    print(f"\nGenerated files:")
    print(f"  1. {detailed_csv}")
    print(f"  2. {summary_csv}")
    print(f"  3. {pivot_csv}")
    

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Aggregate Kaggle evaluation results")
    parser.add_argument(
        "--output-dir",
        type=str,
        default="/kaggle/working/BiomedCoOp/output_eval",
        help="Path to evaluation output directory"
    )
    parser.add_argument(
        "--results-dir",
        type=str,
        default="/kaggle/working/BiomedCoOp/results",
        help="Path to save aggregated results"
    )
    
    args = parser.parse_args()
    main(args)
