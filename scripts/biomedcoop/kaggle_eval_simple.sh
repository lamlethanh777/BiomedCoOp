#!/bin/bash

# Simplified Master Script for Kaggle Evaluation
# Run this script on Kaggle to evaluate all datasets with different k-shot values

# Configuration
WORK_DIR=/kaggle/working/BiomedCoOp
DATA_INPUT=/kaggle/input/biomedcoop-datasets
DATA_DIR=${WORK_DIR}/data
RESULTS_DIR=${WORK_DIR}/results

# Create results directory
mkdir -p ${RESULTS_DIR}

# List of datasets
DATASETS=(btmri busi chmnist covid ctkidney dermamnist kneexray kvasir lungcolon octmnist retina)

# Shot values
SHOTS=(1 2 4 8 16)

echo "========================================"
echo "Kaggle Evaluation Pipeline"
echo "========================================"
echo "Work Directory: ${WORK_DIR}"
echo ""

# Process each dataset
for dataset in "${DATASETS[@]}"; do
    dataset_upper=$(echo "$dataset" | tr '[:lower:]' '[:upper:]')
    
    echo "========================================"
    echo "Dataset: ${dataset_upper}"
    echo "========================================"
    
    # Copy dataset
    echo "Copying ${dataset_upper}..."
    cp -r ${DATA_INPUT}/${dataset_upper} ${DATA_DIR}/
    
    # Run evaluations for all shot values
    for k in "${SHOTS[@]}"; do
        echo "Running ${k}-shot evaluation..."
        bash scripts/biomedcoop/eval_fewshot.sh ${DATA_DIR} ${dataset} ${k}
    done
    
    # Clean up downloaded models to save space
    echo "Cleaning up models for ${dataset}..."
    model_dir="few_shot/${dataset}"
    if [ -d "$model_dir" ]; then
        rm -rf "$model_dir"
        echo "✓ Removed model checkpoints for ${dataset}"
    fi
    
    echo "Completed ${dataset_upper}"
    echo ""
done

echo "========================================"
echo "All evaluations completed!"
echo "========================================"
echo "Now run the aggregation script:"
echo "python aggregate_kaggle_results.py"
