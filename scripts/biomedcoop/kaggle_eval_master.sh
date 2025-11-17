#!/bin/bash

# Master script for running evaluation on Kaggle
# This script:
# 1. Copies datasets
# 2. Runs evaluations with different k-shot values
# 3. Gathers and aggregates results

# Configuration
WORK_DIR=/kaggle/working/BiomedCoOp
DATA_INPUT=/kaggle/input/biomedcoop-datasets
DATA_DIR=${WORK_DIR}/data
OUTPUT_DIR=${WORK_DIR}/output_eval
RESULTS_DIR=${WORK_DIR}/results

# Create results directory
mkdir -p ${RESULTS_DIR}

# List of datasets
DATASETS=(
    "btmri"
    "busi"
    "chmnist"
    "covid"
    "ctkidney"
    "dermamnist"
    "kneexray"
    "kvasir"
    "lungcolon"
    "octmnist"
    "retina"
)

# Shot values
SHOTS=(1 2 4 8 16)

# Trainer configuration
TRAINER=BiomedCoOp_BiomedCLIP
NCTX=4
CSC=False
CTP=end

# CSV header
echo "dataset,shots,accuracy,std" > ${RESULTS_DIR}/detailed_results.csv
echo "shots,avg_accuracy_across_datasets,std" > ${RESULTS_DIR}/summary_by_shots.csv

# Function to extract accuracy from parse_test_res.py output
extract_accuracy() {
    local output=$1
    # Extract accuracy value from output like "* accuracy: 85.23% +- 2.34%"
    echo "$output" | grep "^\* accuracy:" | sed -E 's/.*: ([0-9.]+)% \+- ([0-9.]+)%.*/\1,\2/'
}

# Function to run evaluation for a single dataset
run_dataset_eval() {
    local dataset=$1
    local dataset_upper=$(echo "$dataset" | tr '[:lower:]' '[:upper:]')
    
    echo "========================================"
    echo "Processing dataset: ${dataset_upper}"
    echo "========================================"
    
    # Copy dataset
    echo "Copying ${dataset_upper} dataset..."
    cp -r ${DATA_INPUT}/${dataset_upper} ${DATA_DIR}/
    
    # Run evaluation for different shot values
    for k in "${SHOTS[@]}"; do
        echo "----------------------------------------"
        echo "Running ${k}-shot evaluation for ${dataset}"
        echo "----------------------------------------"
        
        bash scripts/biomedcoop/eval_fewshot.sh ${DATA_DIR} ${dataset} ${k}
        
        # Parse results
        eval_dir=${OUTPUT_DIR}/${dataset}/shots_${k}/${TRAINER}/nctx${NCTX}_csc${CSC}_ctp${CTP}
        
        if [ -d "$eval_dir" ]; then
            echo "Parsing results for ${dataset} with ${k} shots..."
            result=$(python parse_test_res.py --directory ${eval_dir} --test-log 2>&1)
            echo "$result"
            
            # Extract accuracy and std
            acc_std=$(extract_accuracy "$result")
            if [ ! -z "$acc_std" ]; then
                echo "${dataset},${k},${acc_std}" >> ${RESULTS_DIR}/detailed_results.csv
                echo "Saved: ${dataset},${k},${acc_std}"
            else
                echo "Warning: Could not extract accuracy for ${dataset} with ${k} shots"
            fi
        else
            echo "Warning: Evaluation directory not found: ${eval_dir}"
        fi
    done
    
    # Clean up downloaded models to save space
    echo "Cleaning up models for ${dataset}..."
    model_dir="few_shot/${dataset}"
    if [ -d "$model_dir" ]; then
        rm -rf "$model_dir"
        echo "✓ Removed model checkpoints for ${dataset}"
    fi
    
    # Clean up dataset to save space (optional)
    # rm -rf ${DATA_DIR}/${dataset_upper}
    
    echo "Completed evaluation for ${dataset}"
    echo ""
}

# Main execution
echo "========================================"
echo "Starting Kaggle Evaluation Pipeline"
echo "========================================"
echo "Work Directory: ${WORK_DIR}"
echo "Data Input: ${DATA_INPUT}"
echo "Data Directory: ${DATA_DIR}"
echo "Output Directory: ${OUTPUT_DIR}"
echo "Results Directory: ${RESULTS_DIR}"
echo ""

# Run evaluation for all datasets
for dataset in "${DATASETS[@]}"; do
    run_dataset_eval ${dataset}
done

echo "========================================"
echo "Aggregating Results by Shots"
echo "========================================"

# Aggregate results by shot values
for k in "${SHOTS[@]}"; do
    echo "Processing ${k}-shot results..."
    
    # Extract all accuracies for this k value
    accuracies=$(grep ",${k}," ${RESULTS_DIR}/detailed_results.csv | cut -d',' -f3)
    
    if [ ! -z "$accuracies" ]; then
        # Calculate mean using Python
        avg=$(python -c "
import sys
values = [float(x) for x in '''${accuracies}'''.strip().split('\n') if x]
if values:
    mean = sum(values) / len(values)
    import math
    variance = sum((x - mean) ** 2 for x in values) / len(values)
    std = math.sqrt(variance)
    print(f'{mean:.2f},{std:.2f}')
else:
    print('N/A,N/A')
")
        echo "${k},${avg}" >> ${RESULTS_DIR}/summary_by_shots.csv
        echo "${k}-shot average: ${avg}"
    else
        echo "Warning: No results found for ${k} shots"
        echo "${k},N/A,N/A" >> ${RESULTS_DIR}/summary_by_shots.csv
    fi
done

echo ""
echo "========================================"
echo "Evaluation Pipeline Completed!"
echo "========================================"
echo "Detailed results saved to: ${RESULTS_DIR}/detailed_results.csv"
echo "Summary by shots saved to: ${RESULTS_DIR}/summary_by_shots.csv"
echo ""
echo "View detailed results:"
cat ${RESULTS_DIR}/detailed_results.csv
echo ""
echo "View summary by shots:"
cat ${RESULTS_DIR}/summary_by_shots.csv
