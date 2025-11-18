# Evaluation Pipeline Documentation

This directory contains scripts for running and aggregating BiomedCoOp evaluation results.

## 📁 Files Overview

### Core Evaluation Scripts

- **`eval_fewshot.sh`** - Runs few-shot evaluation for a single dataset and shot value
- **`eval_base2new.sh`** - Runs base-to-new generalization evaluation for a single dataset
- **`eval_single_dataset.sh`** - Runs all evaluations (few-shot + base2new) for a single dataset

### Master Scripts

- **`master_eval.sh`** - Orchestrates evaluation across multiple datasets with options
- **`parse_existing_results.sh`** / **`parse_existing_results.ps1`** - Parse already-run evaluations from `output_eval/`

### Analysis Tools (in root directory)

- **`log_results.py`** - Parses log files and saves metrics to CSV
- **`aggregate_results.py`** - Aggregates CSV results with statistics

## 🚀 Quick Start

### 1. Parse Existing Results

If you already have evaluation results in `output_eval/`, parse them first:

**Windows (PowerShell):**

```powershell
.\scripts\biomedcoop\parse_existing_results.ps1
```

**Linux/Mac (Bash):**

```bash
bash scripts/biomedcoop/parse_existing_results.sh
```

This will create:

- `few_shot_BiomedCoOp_BiomedCLIP.csv`
- `base2new_BiomedCoOp_BiomedCLIP.csv`

### 2. View Aggregated Results

**Group by shots (across all datasets):**

```bash
python aggregate_results.py --task few_shot --group-by shots
```

**Group by dataset (across all shots):**

```bash
python aggregate_results.py --task few_shot --group-by dataset
```

**Group by dataset and shot (across seeds):**

```bash
python aggregate_results.py --task few_shot --group-by dataset_shot
```

**Base2New results:**

```bash
python aggregate_results.py --task base2new --group-by dataset
```

### 3. Export to CSV

```bash
python aggregate_results.py --task few_shot --group-by dataset_shot --output summary.csv
```

## 📊 CSV Output Format

### Few-Shot CSV (`few_shot_BiomedCoOp_BiomedCLIP.csv`)

| Column            | Description                                      |
| ----------------- | ------------------------------------------------ |
| `model`           | Model/trainer name (e.g., BiomedCoOp_BiomedCLIP) |
| `checkpoint_name` | Path to model checkpoint                         |
| `dataset`         | Dataset name (e.g., btmri, covid, etc.)          |
| `shot`            | Number of shots (1, 2, 4, 8, 16)                 |
| `seed`            | Random seed (1, 2, 3)                            |
| `accuracy`        | Test accuracy (%)                                |
| `eval_time`       | Evaluation time in seconds                       |
| `timestamp`       | When the result was logged                       |
| `notes`           | Additional notes (optional)                      |

### Base2New CSV (`base2new_BiomedCoOp_BiomedCLIP.csv`)

| Column            | Description                                   |
| ----------------- | --------------------------------------------- |
| `model`           | Model/trainer name                            |
| `checkpoint_name` | Path to model checkpoint                      |
| `dataset`         | Dataset name                                  |
| `shot`            | Number of shots (always 16 for base2new)      |
| `seed`            | Random seed (1, 2, 3)                         |
| `base_acc`        | Accuracy on base classes (%)                  |
| `new_acc`         | Accuracy on novel classes (%)                 |
| `harmonic_mean`   | Harmonic mean of base and new accuracy        |
| `eval_time`       | Total evaluation time (base + new) in seconds |
| `timestamp`       | When the result was logged                    |
| `notes`           | Additional notes (optional)                   |

## 🔧 Advanced Usage

### Run Master Evaluation

**Run all datasets:**

```bash
bash scripts/biomedcoop/master_eval.sh
```

**Run specific datasets:**

```bash
bash scripts/biomedcoop/master_eval.sh --datasets btmri,busi,covid
```

**Run only few-shot:**

```bash
bash scripts/biomedcoop/master_eval.sh --tasks few_shot
```

**Custom shots:**

```bash
bash scripts/biomedcoop/master_eval.sh --datasets covid --shots 1,4,16
```

**Skip cleanup (keep datasets and models):**

```bash
bash scripts/biomedcoop/master_eval.sh --skip-cleanup
```

### Parse Existing Results Options

**PowerShell:**

```powershell
# Parse only few-shot
.\scripts\biomedcoop\parse_existing_results.ps1 -Task "few_shot"

# Parse only base2new
.\scripts\biomedcoop\parse_existing_results.ps1 -Task "base2new"

# Custom model name
.\scripts\biomedcoop\parse_existing_results.ps1 -Model "BiomedCoOp_PubMedCLIP"

# Custom output directory
.\scripts\biomedcoop\parse_existing_results.ps1 -OutputDir "custom_output"
```

**Bash:**

```bash
# Parse only few-shot
bash scripts/biomedcoop/parse_existing_results.sh --task few_shot

# Parse only base2new
bash scripts/biomedcoop/parse_existing_results.sh --task base2new

# Custom model name
bash scripts/biomedcoop/parse_existing_results.sh --model BiomedCoOp_PubMedCLIP
```

### Aggregate Results Options

**Use 95% confidence interval instead of std:**

```bash
python aggregate_results.py --task few_shot --group-by shots --ci95
```

**Different model:**

```bash
python aggregate_results.py --task few_shot --group-by shots --model BiomedCoOp_PubMedCLIP
```

## 📈 Typical Workflow

### For Existing Results

```bash
# 1. Parse all existing evaluations
.\scripts\biomedcoop\parse_existing_results.ps1

# 2. View results grouped by shots
python aggregate_results.py --task few_shot --group-by shots

# 3. View results grouped by dataset
python aggregate_results.py --task few_shot --group-by dataset

# 4. View base2new results
python aggregate_results.py --task base2new --group-by dataset

# 5. Export detailed summary
python aggregate_results.py --task few_shot --group-by dataset_shot --output detailed_summary.csv
```

### For New Evaluations

```bash
# 1. Run master evaluation on specific datasets
bash scripts/biomedcoop/master_eval.sh --datasets btmri,busi

# 2. Results are automatically logged to CSV during evaluation

# 3. View aggregated results
python aggregate_results.py --task few_shot --group-by shots
```

## 🗂️ Directory Structure

```
output_eval/
├── btmri/
│   ├── shots_1/
│   │   └── BiomedCoOp_BiomedCLIP/
│   │       └── nctx4_cscFalse_ctpend/
│   │           ├── seed1/
│   │           │   └── log.txt
│   │           ├── seed2/
│   │           │   └── log.txt
│   │           └── seed3/
│   │               └── log.txt
│   ├── shots_2/
│   ├── shots_4/
│   ├── shots_8/
│   └── shots_16/
├── busi/
│   └── ...
└── base2new/
    ├── test_base/
    │   └── btmri/
    │       └── shots_16/
    │           └── BiomedCoOp_BiomedCLIP/
    │               └── nctx4_cscFalse_ctpend/
    │                   ├── seed1/
    │                   │   └── log.txt
    │                   ├── seed2/
    │                   └── seed3/
    └── test_new/
        └── ...
```

## 📝 Available Datasets

- `btmri` - Brain Tumor MRI
- `busi` - Breast Ultrasound
- `chmnist` - Chest MNIST
- `covid` - COVID-19
- `ctkidney` - CT Kidney
- `dermamnist` - Dermatology MNIST
- `kneexray` - Knee X-Ray
- `kvasir` - Kvasir
- `lungcolon` - Lung & Colon
- `octmnist` - OCT MNIST
- `retina` - Retina

## 🎯 Example Outputs

### Aggregated by Shots

```
================================================================================
Few-Shot Results Grouped by Shots
================================================================================
shot | num_evaluations | accuracy_mean | accuracy_std | eval_time_mean | eval_time_std
-----------------------------------------------------------------------------------
1    | 33              | 68.45         | 12.34        | 45.23          | 8.12
2    | 33              | 72.18         | 11.87        | 46.34          | 7.98
4    | 33              | 76.92         | 10.45        | 47.12          | 8.45
8    | 33              | 80.34         | 9.23         | 48.67          | 8.78
16   | 33              | 82.56         | 8.67         | 50.23          | 9.12
================================================================================
```

### Aggregated by Dataset

```
================================================================================
Few-Shot Results Grouped by Dataset
================================================================================
dataset    | num_evaluations | accuracy_mean | accuracy_std | eval_time_mean
--------------------------------------------------------------------------------
btmri      | 15              | 75.34         | 8.45         | 47.23
busi       | 15              | 78.92         | 7.89         | 45.67
chmnist    | 15              | 82.45         | 6.78         | 48.91
...
================================================================================
```

## ⚠️ Notes

- Evaluation times are only recorded for newly run evaluations (not parsed from existing results)
- The scripts assume the standard directory structure from BiomedCoOp
- For Kaggle environments, adjust paths in `master_eval.sh` as needed
- CSV files are appended to, not overwritten, so you can incrementally add results
