#!/bin/bash

# Parse Existing Results Script
# This script parses all existing evaluation results from output_eval directory
# and populates the CSV files with metrics
#
# Usage:
#   bash scripts/biomedcoop/parse_existing_results.sh [options]
#
# Options:
#   --task <type>        Parse only specific task: few_shot, base2new, or both (default: both)
#   --model <name>       Model name (default: BiomedCoOp_BiomedCLIP)
#   --output-dir <path>  Output eval directory (default: output_eval)

# Default configuration
TASKS=(few_shot base2new)
MODEL=BiomedCoOp_BiomedCLIP
OUTPUT_DIR="output_eval"
WORK_DIR=$(pwd)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --task)
            IFS=',' read -ra TASKS <<< "$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: bash scripts/biomedcoop/parse_existing_results.sh [options]"
            echo ""
            echo "Options:"
            echo "  --task <type>        Parse only: few_shot, base2new, or both (default: both)"
            echo "  --model <name>       Model name (default: BiomedCoOp_BiomedCLIP)"
            echo "  --output-dir <path>  Output directory (default: output_eval)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "========================================"
echo "Parse Existing Results Script"
echo "========================================"
echo "Tasks: ${TASKS[*]}"
echo "Model: ${MODEL}"
echo "Output directory: ${OUTPUT_DIR}"
echo "========================================"
echo ""

TOTAL_PARSED=0

# Parse few-shot results
if [[ " ${TASKS[@]} " =~ " few_shot " ]]; then
    echo "========================================"
    echo "Parsing Few-Shot Results"
    echo "========================================"
    
    # Find all few-shot result directories
    # Structure: output_eval/{dataset}/shots_{K}/{MODEL}/nctx4_cscFalse_ctpend/seed{N}/log.txt
    
    for dataset_dir in ${OUTPUT_DIR}/*/; do
        dataset_name=$(basename "$dataset_dir")
        
        # Skip base2new directory
        if [ "$dataset_name" == "base2new" ]; then
            continue
        fi
        
        for shots_dir in ${dataset_dir}shots_*/; do
            if [ ! -d "$shots_dir" ]; then
                continue
            fi
            
            # Extract shot number
            shots_folder=$(basename "$shots_dir")
            shots=${shots_folder#shots_}
            
            model_dir="${shots_dir}${MODEL}/nctx4_cscFalse_ctpend/"
            
            if [ ! -d "$model_dir" ]; then
                continue
            fi
            
            # Process each seed
            for seed_dir in ${model_dir}seed*/; do
                if [ ! -d "$seed_dir" ]; then
                    continue
                fi
                
                seed_folder=$(basename "$seed_dir")
                seed=${seed_folder#seed}
                
                log_file="${seed_dir}log.txt"
                
                if [ -f "$log_file" ]; then
                    echo "Parsing: ${dataset_name}, ${shots}-shot, seed ${seed}"
                    
                    # Call log_results.py without eval_time (since we don't have it)
                    python log_results.py \
                        --task few_shot \
                        --log-file "$log_file" \
                        --model "$MODEL" \
                        --dataset "$dataset_name" \
                        --shot "$shots" \
                        --seed "$seed" \
                        --checkpoint "few_shot/${dataset_name}/shots_${shots}/${MODEL}/nctx4_cscFalse_ctpend/seed${seed}/model.pth.tar-100"
                    
                    ((TOTAL_PARSED++))
                else
                    echo "Warning: Log file not found: $log_file"
                fi
            done
        done
    done
    
    echo ""
    echo "✓ Completed few-shot parsing"
    echo ""
fi

# Parse base2new results
if [[ " ${TASKS[@]} " =~ " base2new " ]]; then
    echo "========================================"
    echo "Parsing Base2New Results"
    echo "========================================"
    
    # Find all base2new result directories
    # Structure: output_eval/base2new/test_{base|new}/{dataset}/shots_16/{MODEL}/nctx4_cscFalse_ctpend/seed{N}/log.txt
    
    base2new_dir="${OUTPUT_DIR}/base2new"
    
    if [ ! -d "$base2new_dir" ]; then
        echo "Warning: base2new directory not found at ${base2new_dir}"
    else
        for subtask_dir in ${base2new_dir}/test_*/; do
            if [ ! -d "$subtask_dir" ]; then
                continue
            fi
            
            subtask_folder=$(basename "$subtask_dir")
            subtask=${subtask_folder#test_}
            
            for dataset_dir in ${subtask_dir}*/; do
                if [ ! -d "$dataset_dir" ]; then
                    continue
                fi
                
                dataset_name=$(basename "$dataset_dir")
                
                shots_dir="${dataset_dir}shots_16/"
                
                if [ ! -d "$shots_dir" ]; then
                    continue
                fi
                
                model_dir="${shots_dir}${MODEL}/nctx4_cscFalse_ctpend/"
                
                if [ ! -d "$model_dir" ]; then
                    continue
                fi
                
                # Process each seed
                for seed_dir in ${model_dir}seed*/; do
                    if [ ! -d "$seed_dir" ]; then
                        continue
                    fi
                    
                    seed_folder=$(basename "$seed_dir")
                    seed=${seed_folder#seed}
                    
                    log_file="${seed_dir}log.txt"
                    
                    if [ -f "$log_file" ]; then
                        echo "Parsing: ${dataset_name}, base2new (${subtask}), seed ${seed}"
                        
                        # Call log_results.py
                        python log_results.py \
                            --task base2new \
                            --log-file "$log_file" \
                            --model "$MODEL" \
                            --dataset "$dataset_name" \
                            --shot 16 \
                            --seed "$seed" \
                            --checkpoint "base2new/train_base/${dataset_name}/shots_16/${MODEL}/nctx4_cscFalse_ctpend/seed${seed}/model.pth.tar-50" \
                            --subtask "$subtask"
                        
                        ((TOTAL_PARSED++))
                    else
                        echo "Warning: Log file not found: $log_file"
                    fi
                done
            done
        done
    fi
    
    echo ""
    echo "✓ Completed base2new parsing"
    echo ""
fi

echo "========================================"
echo "PARSING COMPLETED!"
echo "========================================"
echo "Total log files parsed: ${TOTAL_PARSED}"
echo ""
echo "CSV files created/updated:"
if [[ " ${TASKS[@]} " =~ " few_shot " ]]; then
    echo "  - few_shot_${MODEL}.csv"
fi
if [[ " ${TASKS[@]} " =~ " base2new " ]]; then
    echo "  - base2new_${MODEL}.csv"
fi
echo ""
echo "To view aggregated results, run:"
echo "  python aggregate_results.py --task few_shot --group-by shots"
echo "  python aggregate_results.py --task few_shot --group-by dataset"
echo "  python aggregate_results.py --task base2new --group-by dataset"
echo "========================================"
