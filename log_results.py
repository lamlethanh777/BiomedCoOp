"""
Log evaluation results to CSV files.

This script parses log.txt files from evaluation runs and appends results
to CSV files for tracking performance across different configurations.

Usage:
    python log_results.py --task few_shot --log-file <path> --model <model_name> \\
        --dataset <dataset> --shot <k> --seed <seed> --eval-time <seconds> \\
        --checkpoint <checkpoint_name>

    python log_results.py --task base2new --log-file <path> --model <model_name> \\
        --dataset <dataset> --shot <k> --seed <seed> --eval-time <seconds> \\
        --checkpoint <checkpoint_name> --subtask <base|new>
"""

import argparse
import csv
import os
import re
from datetime import datetime
from pathlib import Path


def parse_log_file(log_file_path, task="few_shot"):
    """
    Parse log.txt file to extract evaluation metrics.
    
    Args:
        log_file_path: Path to log.txt file
        task: Either 'few_shot' or 'base2new'
    
    Returns:
        Dictionary with extracted metrics
    """
    metrics = {}
    
    if not os.path.exists(log_file_path):
        print(f"Warning: Log file not found: {log_file_path}")
        return metrics
    
    with open(log_file_path, 'r') as f:
        lines = f.readlines()
    
    # Look for the result section (after "=> result" marker)
    found_result = False
    for line in lines:
        line = line.strip()
        
        if "=> result" in line:
            found_result = True
            continue
        
        if found_result:
            # Extract accuracy
            acc_match = re.search(r'\* accuracy: ([\d.]+)%', line)
            if acc_match:
                metrics['accuracy'] = float(acc_match.group(1))
            
            # Extract other potential metrics (precision, recall, f1, etc.)
            for metric_name in ['precision', 'recall', 'f1_score', 'balanced_accuracy']:
                metric_match = re.search(rf'\* {metric_name}: ([\d.]+)%', line)
                if metric_match:
                    metrics[metric_name] = float(metric_match.group(1))
    
    return metrics


def log_few_shot_result(args, metrics):
    """Log few-shot evaluation results to CSV."""
    csv_file = f"few_shot_{args.model}.csv"
    file_exists = os.path.exists(csv_file)
    
    # Define CSV columns
    fieldnames = [
        'model', 'checkpoint_name', 'dataset', 'shot', 'seed',
        'accuracy', 'eval_time', 'timestamp', 'notes'
    ]
    
    # Add optional metric columns if they exist
    for metric in ['precision', 'recall', 'f1_score', 'balanced_accuracy']:
        if metric in metrics:
            if metric not in fieldnames:
                fieldnames.insert(-2, metric)  # Insert before timestamp
    
    with open(csv_file, 'a', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        
        # Write header if file is new
        if not file_exists:
            writer.writeheader()
        
        # Prepare row data
        row = {
            'model': args.model,
            'checkpoint_name': args.checkpoint or 'N/A',
            'dataset': args.dataset,
            'shot': args.shot,
            'seed': args.seed,
            'accuracy': metrics.get('accuracy', 'N/A'),
            'eval_time': f"{args.eval_time:.2f}" if args.eval_time else 'N/A',
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'notes': args.notes or ''
        }
        
        # Add optional metrics
        for metric in ['precision', 'recall', 'f1_score', 'balanced_accuracy']:
            if metric in metrics:
                row[metric] = metrics[metric]
        
        writer.writerow(row)
    
    print(f"✓ Logged to {csv_file}: {args.dataset}, {args.shot}-shot, seed {args.seed}, acc={metrics.get('accuracy', 'N/A'):.2f}%")


def log_base2new_result(args, metrics):
    """Log base2new evaluation results to CSV."""
    csv_file = f"base2new_{args.model}.csv"
    file_exists = os.path.exists(csv_file)
    
    # For base2new, we need to track both base and new accuracies
    # This function is called twice per seed (once for base, once for new)
    # We'll store intermediate results in a temp location and combine them
    
    fieldnames = [
        'model', 'checkpoint_name', 'dataset', 'shot', 'seed',
        'base_acc', 'new_acc', 'harmonic_mean', 'eval_time',
        'timestamp', 'notes'
    ]
    
    # Read existing data to check if we need to update a row
    existing_rows = []
    if file_exists:
        with open(csv_file, 'r', newline='') as f:
            reader = csv.DictReader(f)
            existing_rows = list(reader)
    
    # Find if there's already a row for this configuration
    matching_row = None
    for row in existing_rows:
        if (row['dataset'] == args.dataset and 
            row['shot'] == str(args.shot) and 
            row['seed'] == str(args.seed) and
            row['model'] == args.model):
            matching_row = row
            break
    
    if matching_row:
        # Update existing row
        if args.subtask == 'base':
            matching_row['base_acc'] = metrics.get('accuracy', 'N/A')
        else:  # new
            matching_row['new_acc'] = metrics.get('accuracy', 'N/A')
        
        # Calculate harmonic mean if both are available
        if matching_row.get('base_acc') and matching_row.get('new_acc'):
            try:
                base = float(matching_row['base_acc'])
                new = float(matching_row['new_acc'])
                h_mean = 2 * base * new / (base + new) if (base + new) > 0 else 0
                matching_row['harmonic_mean'] = f"{h_mean:.2f}"
            except (ValueError, TypeError):
                matching_row['harmonic_mean'] = 'N/A'
        
        # Update eval_time (accumulate if both subtasks)
        if args.eval_time:
            current_time = float(matching_row.get('eval_time', 0))
            matching_row['eval_time'] = f"{current_time + args.eval_time:.2f}"
        
        matching_row['timestamp'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
    else:
        # Create new row
        matching_row = {
            'model': args.model,
            'checkpoint_name': args.checkpoint or 'N/A',
            'dataset': args.dataset,
            'shot': args.shot,
            'seed': args.seed,
            'base_acc': metrics.get('accuracy', 'N/A') if args.subtask == 'base' else '',
            'new_acc': metrics.get('accuracy', 'N/A') if args.subtask == 'new' else '',
            'harmonic_mean': '',
            'eval_time': f"{args.eval_time:.2f}" if args.eval_time else 'N/A',
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'notes': args.notes or ''
        }
        existing_rows.append(matching_row)
    
    # Write all rows back
    with open(csv_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(existing_rows)
    
    print(f"✓ Logged to {csv_file}: {args.dataset}, {args.subtask}, seed {args.seed}, acc={metrics.get('accuracy', 'N/A'):.2f}%")


def main():
    parser = argparse.ArgumentParser(description='Log evaluation results to CSV')
    parser.add_argument('--task', type=str, required=True, choices=['few_shot', 'base2new'],
                        help='Evaluation task type')
    parser.add_argument('--log-file', type=str, required=True,
                        help='Path to log.txt file')
    parser.add_argument('--model', type=str, required=True,
                        help='Model name (e.g., BiomedCoOp_BiomedCLIP)')
    parser.add_argument('--dataset', type=str, required=True,
                        help='Dataset name')
    parser.add_argument('--shot', type=int, required=True,
                        help='Number of shots')
    parser.add_argument('--seed', type=int, required=True,
                        help='Random seed')
    parser.add_argument('--eval-time', type=float, default=None,
                        help='Evaluation time in seconds')
    parser.add_argument('--checkpoint', type=str, default=None,
                        help='Checkpoint name or path')
    parser.add_argument('--subtask', type=str, choices=['base', 'new'],
                        help='Subtask for base2new (base or new)')
    parser.add_argument('--notes', type=str, default='',
                        help='Additional notes')
    
    args = parser.parse_args()
    
    # Validate args
    if args.task == 'base2new' and not args.subtask:
        parser.error("--subtask is required for base2new task")
    
    # Parse log file
    metrics = parse_log_file(args.log_file, args.task)
    
    if not metrics:
        print(f"Warning: No metrics found in {args.log_file}")
        metrics = {'accuracy': 'N/A'}
    
    # Log results
    if args.task == 'few_shot':
        log_few_shot_result(args, metrics)
    else:  # base2new
        log_base2new_result(args, metrics)


if __name__ == '__main__':
    main()
