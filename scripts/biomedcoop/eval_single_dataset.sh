#!/bin/bash

# Single Dataset Evaluation Script
# This script runs few-shot and base2new evaluations for a single dataset
#
# Usage:
#   bash scripts/biomedcoop/eval_single_dataset.sh <dataset_name>
#
# Example:
#   bash scripts/biomedcoop/eval_single_dataset.sh btmri
#
# Available datasets:
#   btmri, busi, chmnist, covid, ctkidney, dermamnist, 
#   kneexray, kvasir, lungcolon, octmnist, retina

# Check if dataset argument is provided
if [ -z "$1" ]; then
    echo "Error: No dataset specified"
    echo "Usage: bash $0 <dataset_name>"
    echo ""
    echo "Available datasets:"
    echo "  btmri, busi, chmnist, covid, ctkidney, dermamnist,"
    echo "  kneexray, kvasir, lungcolon, octmnist, retina"
    exit 1
fi

# Configuration
DATASET=$1

# Map dataset names to actual folder names
case "$DATASET" in
    btmri)
        DATASET_FOLDER="BTMRI"
        ;;
    busi)
        DATASET_FOLDER="BUSI"
        ;;
    chmnist)
        DATASET_FOLDER="CHMNIST"
        ;;
    covid)
        DATASET_FOLDER="COVID_19"
        ;;
    ctkidney)
        DATASET_FOLDER="CTKidney"
        ;;
    dermamnist)
        DATASET_FOLDER="DermaMNIST"
        ;;
    kneexray)
        DATASET_FOLDER="KneeXray"
        ;;
    kvasir)
        DATASET_FOLDER="Kvasir"
        ;;
    lungcolon)
        DATASET_FOLDER="LungColon"
        ;;
    octmnist)
        DATASET_FOLDER="OCTMNIST"
        ;;
    retina)
        DATASET_FOLDER="RETINA"
        ;;
    *)
        echo "Error: Unknown dataset '${DATASET}'"
        echo "Available datasets:"
        echo "  btmri, busi, chmnist, covid, ctkidney, dermamnist,"
        echo "  kneexray, kvasir, lungcolon, octmnist, retina"
        exit 1
        ;;
esac

# Paths for Kaggle
DATA_INPUT="/kaggle/input/biomedcoop-datasets/${DATASET_FOLDER}"
DATA_DIR="/kaggle/working/BiomedCoOp/data"
WORK_DIR="/kaggle/working/BiomedCoOp"

# Shot values
SHOTS=(1 2 4 8 16)

echo "========================================"
echo "BiomedCoOp Dataset Evaluation"
echo "========================================"
echo "Dataset: ${DATASET} (Folder: ${DATASET_FOLDER})"
echo "Data Input: ${DATA_INPUT}"
echo "Data Directory: ${DATA_DIR}"
echo "Working Directory: ${WORK_DIR}"
echo ""

# Step 1: Copy dataset
echo "========================================"
echo "Step 1: Copying Dataset"
echo "========================================"
echo "Copying ${DATASET_FOLDER} dataset..."
cp -r ${DATA_INPUT} ${DATA_DIR}/
echo "✓ Dataset copied to ${DATA_DIR}/${DATASET_FOLDER}"
echo ""

# Step 2: Run few-shot evaluations
echo "========================================"
echo "Step 2: Few-Shot Evaluations"
echo "========================================"

for k in "${SHOTS[@]}"; do
    echo "----------------------------------------"
    echo "Running ${k}-shot evaluation for ${DATASET}"
    echo "----------------------------------------"
    
    # Run evaluation
    bash ${WORK_DIR}/scripts/biomedcoop/eval_fewshot.sh ${DATA_DIR} ${DATASET} ${k}
    
    # Clean up models
    echo "Cleaning up models for ${k}-shot..."
    rm -rf ${WORK_DIR}/few_shot
    mkdir -p ${WORK_DIR}/few_shot
    
    echo "✓ Completed ${k}-shot evaluation for ${DATASET}"
    echo ""
done

echo "✓ All few-shot evaluations completed"
echo ""

# Step 3: Run base2new evaluation
echo "========================================"
echo "Step 3: Base2New Evaluation"
echo "========================================"
echo "Running Base2New evaluation for ${DATASET}..."

bash ${WORK_DIR}/scripts/biomedcoop/eval_base2new.sh ${DATA_DIR} ${DATASET} 16 BiomedCLIP

# Clean up base2new models
echo "Cleaning up base2new models..."
rm -rf ${WORK_DIR}/base2new
mkdir -p ${WORK_DIR}/base2new

echo "✓ Completed Base2New evaluation for ${DATASET}"
echo ""

# Step 4: Cleanup dataset
echo "========================================"
echo "Step 4: Cleanup"
echo "========================================"
echo "Removing ${DATASET_FOLDER} dataset from working directory..."
rm -rf ${DATA_DIR}/${DATASET_FOLDER}
echo "✓ Dataset removed"
echo ""

# Final summary
echo "========================================"
echo "EVALUATION COMPLETED!"
echo "========================================"
echo "Dataset: ${DATASET} (Folder: ${DATASET_FOLDER})"
echo "Evaluations performed:"
echo "  - Few-shot: 1, 2, 4, 8, 16 shots"
echo "  - Base2New: 16 shots"
echo ""
echo "Results saved to:"
echo "  ${WORK_DIR}/output_eval/${DATASET}/"
echo ""
echo "To view results, run:"
echo "  python parse_test_res.py --directory ${WORK_DIR}/output_eval/${DATASET}/shots_<K>/BiomedCoOp_BiomedCLIP/nctx4_cscFalse_ctpend --test-log"
echo "========================================"
