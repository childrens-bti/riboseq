# `riboseq`

The `riboseq` workflow is an nf-core pipeline for ribosome profiling data analysis that processes ribosome footprinting sequencing data.

The workflow processes FASTQ files from ribosome profiling experiments using various tools to:

- Trim adapter sequences and filter reads
- Align reads to reference genomes
- Generate ribosome occupancy profiles
- Perform quality control assessments
- Analyze ribosome P-site positions
- Calculate translation efficiency metrics

The pipeline supports both single-end and paired-end sequencing data and can handle multiple samples in a batch.

Full documentation for the workflow is available in the [nf-core/riboseq GitHub repository](https://github.com/nf-core/riboseq).

## Steps to run the workflow on Cavatica

To run the `riboseq` workflow on Cavatica, you will need to follow the following steps:

1. Upload all required input files to your Cavatica project
2. Prepare a samplesheet file with sample information and file paths. See [Required input files](#required-input-files) for more details.
3. Transform the paths in the samplesheet to Cavatica `vs://` paths using the `sbmanifest` tool.
4. Set options and run the `riboseq` workflow on Cavatica using the web interface.

## Required input files

### Primary inputs

- **Input samplesheet**: A CSV file containing sample information and paths to FASTQ files
- **Reference genome FASTA**: Reference genome sequence file
- **Genome annotation GTF/GFF**: Gene annotation file for the reference genome

### Optional inputs

- **Transcript FASTA**: For transcript-level analysis
- **Custom adapter sequences**: For non-standard adapter trimming
- **Blacklist regions**: Genomic regions to exclude from analysis

## Samplesheet format

The input samplesheet should be a CSV file with the following columns:

```csv
sample,fastq_1,fastq_2
SAMPLE_PE,sample_R1.fastq.gz,sample_R2.fastq.gz
SAMPLE_SE,sample.fastq.gz,
```

- `sample`: Sample identifier
- `fastq_1`: Path to the first FASTQ file
- `fastq_2`: Path to the second FASTQ file (for paired-end data, leave empty for single-end)

## Output files

The workflow generates various output files including:

- Quality control reports
- Alignment statistics
- Ribosome occupancy profiles
- P-site position analyses
- Translation efficiency metrics
- MultiQC summary report
