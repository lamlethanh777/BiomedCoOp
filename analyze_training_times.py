"""
Analyze training time results from the CSV file.

This script provides various analyses of training times logged in training_times.csv.
"""

import pandas as pd
import os
import sys


def load_training_data(csv_path='train-results/training_times.csv'):
    """Load training data from CSV file."""
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        print("No training runs have been logged yet.")
        return None
    
    df = pd.read_csv(csv_path)
    return df


def analyze_by_dataset(df):
    """Analyze training times grouped by dataset."""
    print("\n" + "="*60)
    print("TRAINING TIME BY DATASET")
    print("="*60)
    
    grouped = df.groupby('dataset')['duration_seconds'].agg(['mean', 'min', 'max', 'count'])
    grouped.columns = ['Avg Time (s)', 'Min Time (s)', 'Max Time (s)', 'Runs']
    
    # Convert to hours:minutes:seconds for better readability
    for col in ['Avg Time (s)', 'Min Time (s)', 'Max Time (s)']:
        grouped[col.replace(' (s)', ' (HH:MM:SS)')] = grouped[col].apply(seconds_to_hms)
    
    print(grouped.to_string())


def analyze_by_trainer(df):
    """Analyze training times grouped by trainer."""
    print("\n" + "="*60)
    print("TRAINING TIME BY TRAINER/METHOD")
    print("="*60)
    
    grouped = df.groupby('trainer')['duration_seconds'].agg(['mean', 'min', 'max', 'count'])
    grouped.columns = ['Avg Time (s)', 'Min Time (s)', 'Max Time (s)', 'Runs']
    
    for col in ['Avg Time (s)', 'Min Time (s)', 'Max Time (s)']:
        grouped[col.replace(' (s)', ' (HH:MM:SS)')] = grouped[col].apply(seconds_to_hms)
    
    print(grouped.to_string())


def analyze_by_shots(df):
    """Analyze training times grouped by number of shots."""
    print("\n" + "="*60)
    print("TRAINING TIME BY NUMBER OF SHOTS")
    print("="*60)
    
    grouped = df.groupby('num_shots')['duration_seconds'].agg(['mean', 'min', 'max', 'count'])
    grouped.columns = ['Avg Time (s)', 'Min Time (s)', 'Max Time (s)', 'Runs']
    
    for col in ['Avg Time (s)', 'Min Time (s)', 'Max Time (s)']:
        grouped[col.replace(' (s)', ' (HH:MM:SS)')] = grouped[col].apply(seconds_to_hms)
    
    print(grouped.to_string())


def analyze_recent_runs(df, n=10):
    """Show the most recent training runs."""
    print("\n" + "="*60)
    print(f"RECENT {n} TRAINING RUNS")
    print("="*60)
    
    recent = df.tail(n)[['timestamp', 'dataset', 'trainer', 'num_shots', 
                         'duration_formatted', 'seed']]
    print(recent.to_string(index=False))


def seconds_to_hms(seconds):
    """Convert seconds to HH:MM:SS format."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def print_summary(df):
    """Print overall summary statistics."""
    print("\n" + "="*60)
    print("OVERALL SUMMARY")
    print("="*60)
    print(f"Total training runs: {len(df)}")
    print(f"Total training time: {seconds_to_hms(df['duration_seconds'].sum())}")
    print(f"Average training time: {seconds_to_hms(df['duration_seconds'].mean())}")
    print(f"Shortest training: {seconds_to_hms(df['duration_seconds'].min())}")
    print(f"Longest training: {seconds_to_hms(df['duration_seconds'].max())}")
    print(f"\nDatasets trained: {df['dataset'].nunique()}")
    print(f"Trainers/methods used: {df['trainer'].nunique()}")


def main():
    # Load data
    df = load_training_data()
    
    if df is None or len(df) == 0:
        print("No training data available yet.")
        return
    
    # Print all analyses
    print_summary(df)
    analyze_recent_runs(df)
    analyze_by_dataset(df)
    analyze_by_trainer(df)
    analyze_by_shots(df)
    
    print("\n" + "="*60)
    print("Analysis complete!")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
