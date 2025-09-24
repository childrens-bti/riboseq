#!/bin/bash
set -euo pipefail

# Script to convert local file paths in samplesheet to Cavatica vs:// paths
# Usage: ./convert-samplesheet.sh <input_samplesheet.csv> <output_samplesheet.csv>

project_id="chaodi/cruz-riboseq"
input_sheet="${1:-samplesheet.csv}"
output_file="${2:-samplesheet_cavatica.csv}"

if [ ! -f "$input_sheet" ]; then
    echo "Error: Input samplesheet '$input_sheet' not found."
    echo "Usage: $0 <input_samplesheet.csv> [output_samplesheet.csv]"
    exit 1
fi

echo "Converting samplesheet paths from local to Cavatica format..."
echo "Input: $input_sheet"
echo "Output: $output_file"
echo "Project ID: $project_id"

pixi run -e cavatica sbmanifest \
  --profile . \
  --projectid "$project_id" \
  --sample-sheet "$input_sheet" \
  --output "$output_file" \
  --columns fastq_1 fastq_2

echo "Conversion completed. Check '$output_file' for Cavatica-compatible paths."