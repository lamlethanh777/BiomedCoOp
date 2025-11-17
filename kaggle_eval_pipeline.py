# Kaggle Evaluation Master Script
# Run this in a Kaggle notebook to evaluate all datasets

import os
import subprocess
import pandas as pd
import numpy as np
import re
from pathlib import Path

# Configuration
WORK_DIR = "/kaggle/working/BiomedCoOp"
DATA_INPUT = "/kaggle/input/biomedcoop-datasets"
DATA_DIR = f"{WORK_DIR}/data"
OUTPUT_DIR = f"{WORK_DIR}/output_eval"
RESULTS_DIR = f"{WORK_DIR}/results"

# Create results directory
os.makedirs(RESULTS_DIR, exist_ok=True)

# Datasets and shot values
DATASETS = [
    "btmri", "busi", "chmnist", "covid", "ctkidney",
    "dermamnist", "kneexray", "kvasir", "lungcolon",
    "octmnist", "retina"
]

SHOTS = [1, 2, 4, 8, 16]

# Trainer configuration
TRAINER = "BiomedCoOp_BiomedCLIP"
CONFIG_SUFFIX = "nctx4_cscFalse_ctpend"


def extract_accuracy_from_output(output_text):
    """Extract accuracy and std from parse_test_res.py output."""
    pattern = r"\* accuracy: ([\d.]+)% \+- ([\d.]+)%"
    match = re.search(pattern, output_text)
    if match:
        return float(match.group(1)), float(match.group(2))
    return None, None


def run_command(cmd, description=""):
    """Run a shell command and return output."""
    if description:
        print(f"\n{description}")
    print(f"Running: {cmd}")
    
    result = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True
    )
    
    print(result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)
    
    return result.stdout, result.stderr, result.returncode


def main():
    print("=" * 80)
    print("KAGGLE EVALUATION PIPELINE")
    print("=" * 80)
    
    # Store all results
    detailed_results = []
    
    # Process each dataset
    for dataset in DATASETS:
        dataset_upper = dataset.upper()
        
        print("\n" + "=" * 80)
        print(f"PROCESSING DATASET: {dataset_upper}")
        print("=" * 80)
        
        # Copy dataset
        print(f"\nCopying {dataset_upper} dataset...")
        cmd = f"cp -r {DATA_INPUT}/{dataset_upper} {DATA_DIR}/"
        run_command(cmd)
        
        # Run evaluations for different shot values
        for k in SHOTS:
            print(f"\n{'-' * 80}")
            print(f"Running {k}-shot evaluation for {dataset}")
            print(f"{'-' * 80}")
            
            # Run evaluation
            eval_cmd = f"bash {WORK_DIR}/scripts/biomedcoop/eval_fewshot.sh {DATA_DIR} {dataset} {k}"
            run_command(eval_cmd, f"Evaluating {dataset} with {k} shots")
            
            # Parse results
            eval_dir = f"{OUTPUT_DIR}/{dataset}/shots_{k}/{TRAINER}/{CONFIG_SUFFIX}"
            
            if os.path.exists(eval_dir):
                parse_cmd = f"cd {WORK_DIR} && python parse_test_res.py --directory {eval_dir} --test-log"
                output, stderr, returncode = run_command(parse_cmd, f"Parsing results for {dataset} - {k} shots")
                
                # Extract accuracy
                acc, std = extract_accuracy_from_output(output)
                
                if acc is not None:
                    detailed_results.append({
                        'dataset': dataset,
                        'shots': k,
                        'accuracy': acc,
                        'std': std
                    })
                    print(f"✓ Saved: {dataset} | {k}-shot | {acc:.2f}% ± {std:.2f}%")
                else:
                    print(f"⚠ Warning: Could not extract accuracy for {dataset} with {k} shots")
            else:
                print(f"⚠ Warning: Evaluation directory not found: {eval_dir}")
        
        # Clean up downloaded models for this dataset to save space
        print(f"\nCleaning up models for {dataset_upper}...")
        model_base_dir = f"{WORK_DIR}/few_shot/{dataset}"
        if os.path.exists(model_base_dir):
            cleanup_cmd = f"rm -rf {model_base_dir}"
            run_command(cleanup_cmd, f"Removing model checkpoints for {dataset}")
            print(f"✓ Cleaned up models for {dataset_upper}")
        
        print(f"\n✓ Completed evaluation for {dataset_upper}")
    
    # Save detailed results
    print("\n" + "=" * 80)
    print("SAVING DETAILED RESULTS")
    print("=" * 80)
    
    df_detailed = pd.DataFrame(detailed_results)
    detailed_csv = f"{RESULTS_DIR}/detailed_results.csv"
    df_detailed.to_csv(detailed_csv, index=False)
    print(f"\n✓ Saved detailed results to: {detailed_csv}")
    print("\nDetailed Results Preview:")
    print(df_detailed.to_string(index=False))
    
    # Aggregate by shots
    print("\n" + "=" * 80)
    print("AGGREGATING RESULTS BY SHOTS")
    print("=" * 80)
    
    summary_by_shots = []
    
    for k in SHOTS:
        shot_data = df_detailed[df_detailed['shots'] == k]
        
        if len(shot_data) > 0:
            avg_acc = shot_data['accuracy'].mean()
            std_acc = shot_data['accuracy'].std()
            num_datasets = len(shot_data)
            
            summary_by_shots.append({
                'shots': k,
                'avg_accuracy': avg_acc,
                'std_across_datasets': std_acc,
                'num_datasets': num_datasets
            })
            
            print(f"{k:2d}-shot | Avg: {avg_acc:6.2f}% ± {std_acc:5.2f}% | Datasets: {num_datasets}")
    
    df_summary = pd.DataFrame(summary_by_shots)
    summary_csv = f"{RESULTS_DIR}/summary_by_shots.csv"
    df_summary.to_csv(summary_csv, index=False)
    print(f"\n✓ Saved summary by shots to: {summary_csv}")
    
    # Create pivot table
    print("\n" + "=" * 80)
    print("CREATING PIVOT TABLE")
    print("=" * 80)
    
    pivot_table = df_detailed.pivot(index='dataset', columns='shots', values='accuracy')
    
    # Add average row
    avg_row = pd.DataFrame([pivot_table.mean()], index=['AVERAGE'])
    pivot_table = pd.concat([pivot_table, avg_row])
    
    pivot_csv = f"{RESULTS_DIR}/pivot_table.csv"
    pivot_table.to_csv(pivot_csv)
    print(f"\n✓ Saved pivot table to: {pivot_csv}")
    
    print("\nPivot Table (Dataset vs Shots):")
    print(pivot_table.round(2).to_string())
    
    # Final summary
    print("\n" + "=" * 80)
    print("EVALUATION PIPELINE COMPLETED!")
    print("=" * 80)
    print(f"\nGenerated files in {RESULTS_DIR}:")
    print(f"  1. detailed_results.csv - All individual results")
    print(f"  2. summary_by_shots.csv - Averages across datasets for each k-shot")
    print(f"  3. pivot_table.csv - Matrix view (datasets × shots)")
    
    return df_detailed, df_summary, pivot_table


# Run the pipeline
if __name__ == "__main__":
    df_detailed, df_summary, pivot_table = main()
