#!/usr/bin/env bash
set -euo pipefail

PARALLEL=6
OUTDIR="data"
KEEP_ZIPS=0

URL_BASE="https://huggingface.co/datasets/TahaKoleilat/BiomedCoOp/resolve/main"
datasets=(BTMRI BUSI CHMNIST COVID_19 CTKidney DermaMNIST KneeXray Kvasir LungColon OCTMNIST RETINA)

print_usage() {
  cat <<EOF
Usage: $0 [-j PARALLEL] [-o OUTDIR] [--keep] [-h]

Options:
  -j PARALLEL    Number of concurrent downloads (default: $PARALLEL)
  -o OUTDIR      Output directory to place datasets (default: $OUTDIR)
  --keep         Keep downloaded zip files (default: remove after unzip)
  -h             Show this help message

Notes:
  - Script prefers `aria2c` for fast segmented downloads. Falls back to `wget` or `curl`.
  - Run this in Bash / WSL / Git Bash on Windows.
EOF
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    -j) PARALLEL="$2"; shift 2;;
    -o) OUTDIR="$2"; shift 2;;
    --keep) KEEP_ZIPS=1; shift;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 1;;
  esac
done

mkdir -p "$OUTDIR"

downloader() {
  local url="$1"
  local out="$2"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x16 -s16 -k1M -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$out" "$url"
  elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$out" "$url"
  else
    echo "Error: no downloader found (aria2c, wget or curl required)." >&2
    return 2
  fi
}

download_and_unpack() {
  local name="$1"
  local url="$URL_BASE/${name}.zip"
  local zipfile="$OUTDIR/${name}.zip"

  echo "Starting download: $name"
  if ! downloader "$url" "$zipfile"; then
    echo "Download failed for $name" >&2
    return 1
  fi

  echo "Unzipping $zipfile -> $OUTDIR/$OUTDIR"
  if command -v unzip >/dev/null 2>&1; then
    unzip -o "$zipfile" -d "$OUTDIR/$OUTDIR"
  else
    # Fallback to python unzip if `unzip` is not available
    python - <<PY
import zipfile,sys
zf=zipfile.ZipFile(r'${zipfile}')
zf.extractall(r'${OUTDIR}/${OUTDIR}')
zf.close()
PY
  fi

  if [[ $KEEP_ZIPS -ne 1 ]]; then
    rm -f "$zipfile"
  fi
  echo "Finished: $name"
}

# Concurrency control: run background jobs and keep at most $PARALLEL
pids=()
for name in "${datasets[@]}"; do
  # start job in background
  download_and_unpack "$name" &
  pids+=("$!")

  # wait if we reached concurrency limit
  while [ "$(jobs -rp | wc -l)" -ge "$PARALLEL" ]; do
    sleep 0.4
  done
done

wait

echo "All datasets processed. Files are under: $OUTDIR"
