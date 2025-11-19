#!/bin/bash

# Master Evaluation Script
# This script runs evaluations across multiple datasets with timing and CSV logging

# Store child PID for cleanup
CHILD_PID=""

# Trap SIGINT (Ctrl+C) and SIGTERM for graceful shutdown
cleanup() {
    echo ""
    echo "========================================"
    echo "Interrupted! Cleaning up..."
    echo "========================================"
    
    # Kill child process if running
    if [ -n "$CHILD_PID" ]; then
        echo "Stopping child process (PID: $CHILD_PID)..."
        kill -TERM "$CHILD_PID" 2>/dev/null
        wait "$CHILD_PID" 2>/dev/null
    fi
    
    echo "Cleanup complete. Exiting."
    exit 130
}

trap cleanup INT TERM
#
# Usage:
#   bash scripts/biomedcoop/master_eval.sh [options]
#
# Options:
#   --datasets <list>         Comma-separated list of datasets (default: all)
#                             Example: --datasets btmri,busi,chmnist
#   --tasks <list>            Comma-separated tasks to run: few_shot,base2new (default: both)
#   --shots <list>            Comma-separated shot values for few_shot (default: 1,2,4,8,16)
#   --data-dir <path>         Path to data directory (default: /kaggle/working/BiomedCoOp/data)
#   --skip-dataset-cleanup    Skip cleanup of datasets after evaluation
#   --skip-model-cleanup      Skip cleanup of models after evaluation
#
# Examples:
#   # Run all evaluations on all datasets
#   bash scripts/biomedcoop/master_eval.sh
#
#   # Run only few-shot on specific datasets
#   bash scripts/biomedcoop/master_eval.sh --datasets btmri,busi --tasks few_shot
#
#   # Run with custom shots
#   bash scripts/biomedcoop/master_eval.sh --datasets covid --shots 1,4,16

# Default configuration
ALL_DATASETS=(btmri busi chmnist covid ctkidney dermamnist kneexray kvasir lungcolon octmnist retina)
DATASETS=()
TASKS=(few_shot base2new)
SHOTS=(1 2 4 8 16)
DATA_DIR="/workspace/BiomedCoOp/data"
WORK_DIR="/workspace/BiomedCoOp"
SKIP_DATASET_CLEANUP=false
SKIP_MODEL_CLEANUP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --datasets)
            IFS=',' read -ra DATASETS <<< "$2"
            shift 2
            ;;
        --tasks)
            IFS=',' read -ra TASKS <<< "$2"
            shift 2
            ;;
        --shots)
            IFS=',' read -ra SHOTS <<< "$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --skip-dataset-cleanup)
            SKIP_DATASET_CLEANUP=true
            shift
            ;;
        --skip-model-cleanup)
            SKIP_MODEL_CLEANUP=true
            shift
            ;;
        --help)
            echo "Usage: bash scripts/biomedcoop/master_eval.sh [options]"
            echo ""
            echo "Options:"
            echo "  --datasets <list>         Comma-separated list of datasets"
            echo "  --tasks <list>            Tasks: few_shot,base2new (default: both)"
            echo "  --shots <list>            Shot values for few_shot (default: 1,2,4,8,16)"
            echo "  --data-dir <path>         Path to data directory"
            echo "  --skip-dataset-cleanup    Skip cleanup of datasets after evaluation"
            echo "  --skip-model-cleanup      Skip cleanup of models after evaluation"
            echo ""
            echo "Available datasets:"
            echo "  btmri, busi, chmnist, covid, ctkidney, dermamnist,"
            echo "  kneexray, kvasir, lungcolon, octmnist, retina"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# If no datasets specified, use all
if [ ${#DATASETS[@]} -eq 0 ]; then
    DATASETS=("${ALL_DATASETS[@]}")
fi

# Map dataset names to folder names
get_dataset_folder() {
    case "$1" in
        btmri) echo "BTMRI" ;;
        busi) echo "BUSI" ;;
        chmnist) echo "CHMNIST" ;;
        covid) echo "COVID_19" ;;
        ctkidney) echo "CTKidney" ;;
        dermamnist) echo "DermaMNIST" ;;
        kneexray) echo "KneeXray" ;;
        kvasir) echo "Kvasir" ;;
        lungcolon) echo "LungColon" ;;
        octmnist) echo "OCTMNIST" ;;
        retina) echo "RETINA" ;;
        *) echo "" ;;
    esac
}

# Validate datasets
for dataset in "${DATASETS[@]}"; do
    folder=$(get_dataset_folder "$dataset")
    if [ -z "$folder" ]; then
        echo "Error: Unknown dataset '$dataset'"
        echo "Available datasets: ${ALL_DATASETS[*]}"
        exit 1
    fi
done

# Print configuration
echo "========================================"
echo "Master Evaluation Script"
echo "========================================"
echo "Datasets: ${DATASETS[*]}"
echo "Tasks: ${TASKS[*]}"
if [[ " ${TASKS[@]} " =~ " few_shot " ]]; then
    echo "Shots (few-shot): ${SHOTS[*]}"
fi
echo "Data directory: ${DATA_DIR}"
echo "Working directory: ${WORK_DIR}"
echo "Skip dataset cleanup: ${SKIP_DATASET_CLEANUP}"
echo "Skip model cleanup: ${SKIP_MODEL_CLEANUP}"
echo "========================================"
echo ""

# Track overall start time
MASTER_START=$(date +%s)

# Process each dataset
for dataset in "${DATASETS[@]}"; do
    dataset_folder=$(get_dataset_folder "$dataset")
    
    echo ""
    echo "========================================"
    echo "Processing Dataset: ${dataset} (${dataset_folder})"
    echo "========================================"
    
    DATASET_START=$(date +%s)
    
    # Step 1: Copy dataset
    echo "Step 1: Copying dataset..."
    DATA_INPUT="/kaggle/input/biomedcoop-datasets/${dataset_folder}"
    
    if [ -d "${DATA_INPUT}" ]; then
        cp -r ${DATA_INPUT} ${DATA_DIR}/
        echo "✓ Dataset copied to ${DATA_DIR}/${dataset_folder}"
    else
        echo "⚠ Warning: Dataset not found at ${DATA_INPUT}"
        echo "  Assuming dataset is already in ${DATA_DIR}/${dataset_folder}"
        if [ ! -d "${DATA_DIR}/${dataset_folder}" ]; then
            echo "✗ Error: Dataset not found in either location. Skipping ${dataset}."
            continue
        fi
    fi
    echo ""
    
    # Step 2: Run few-shot evaluations
    if [[ " ${TASKS[@]} " =~ " few_shot " ]]; then
        echo "Step 2: Few-Shot Evaluations"
        echo "----------------------------------------"
        
        for k in "${SHOTS[@]}"; do
            echo "Running ${k}-shot evaluation for ${dataset}..."
            SHOT_START=$(date +%s)
            
            bash ${WORK_DIR}/scripts/biomedcoop/eval_fewshot.sh ${DATA_DIR} ${dataset} ${k} &
            CHILD_PID=$!
            wait $CHILD_PID
            CHILD_PID=""
            
            SHOT_END=$(date +%s)
            SHOT_TIME=$((SHOT_END - SHOT_START))
            echo "✓ Completed ${k}-shot evaluation in ${SHOT_TIME}s"
            
            # Cleanup models if not skipping
            if [ "$SKIP_MODEL_CLEANUP" = false ]; then
                echo "Cleaning up models for ${k}-shot..."
                rm -rf ${WORK_DIR}/few_shot
                mkdir -p ${WORK_DIR}/few_shot
            fi
            echo ""
        done
        
        echo "✓ All few-shot evaluations completed"
        echo ""
    fi
    
    # Step 3: Run base2new evaluation
    if [[ " ${TASKS[@]} " =~ " base2new " ]]; then
        echo "Step 3: Base2New Evaluation"
        echo "----------------------------------------"
        
        BASE2NEW_START=$(date +%s)
        
        bash ${WORK_DIR}/scripts/biomedcoop/eval_base2new.sh ${DATA_DIR} ${dataset} &
        CHILD_PID=$!
        wait $CHILD_PID
        CHILD_PID=""
        
        BASE2NEW_END=$(date +%s)
        BASE2NEW_TIME=$((BASE2NEW_END - BASE2NEW_START))
        echo "✓ Completed Base2New evaluation in ${BASE2NEW_TIME}s"
        
        # Cleanup base2new models if not skipping
        if [ "$SKIP_MODEL_CLEANUP" = false ]; then
            echo "Cleaning up base2new models..."
            rm -rf ${WORK_DIR}/base2new
            mkdir -p ${WORK_DIR}/base2new
        fi
        echo ""
    fi
    
    # Step 4: Cleanup dataset if not skipping
    if [ "$SKIP_DATASET_CLEANUP" = false ]; then
        echo "Step 4: Dataset Cleanup"
        echo "----------------------------------------"
        echo "Removing ${dataset_folder} dataset..."
        rm -rf ${DATA_DIR}/${dataset_folder}
        echo "✓ Dataset removed"
        echo ""
    fi
    
    DATASET_END=$(date +%s)
    DATASET_TIME=$((DATASET_END - DATASET_START))
    
    echo "========================================"
    echo "✓ Completed ${dataset} in ${DATASET_TIME}s"
    echo "========================================"
    echo ""
done

MASTER_END=$(date +%s)
MASTER_TIME=$((MASTER_END - MASTER_START))

# Final summary
echo ""
echo "========================================"
echo "MASTER EVALUATION COMPLETED!"
echo "========================================"
echo "Total time: ${MASTER_TIME}s"
echo "Datasets processed: ${DATASETS[*]}"
echo "Tasks completed: ${TASKS[*]}"
echo ""
echo "Results logged to CSV files:"
if [[ " ${TASKS[@]} " =~ " few_shot " ]]; then
    echo "  - few_shot_BiomedCoOp_BiomedCLIP.csv"
fi
if [[ " ${TASKS[@]} " =~ " base2new " ]]; then
    echo "  - base2new_BiomedCoOp_BiomedCLIP.csv"
fi
echo ""
echo "To aggregate results, run:"
echo "  python aggregate_results.py --task few_shot --group-by shots"
echo "  python aggregate_results.py --task few_shot --group-by dataset"
echo "  python aggregate_results.py --task base2new --group-by dataset"
echo "========================================"
