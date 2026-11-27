# Output policy

This document defines what this fork of nf-core/riboseq publishes on CAVATICA, and what is kept only inside the task. For a description of each output file, see [output.md](output.md).

> Status: implemented in the pipeline; not yet in a tagged release.

## Only exported files are published

The pipeline keeps nf-core's `results/` layout inside the task, so upstream updates still merge cleanly. When a run succeeds, its completion handler (`exportFlat` in `subworkflows/local/utils_nfcore_riboseq_pipeline/main.nf`) links the files analysis uses into `<outdir>/export/`, flat (no folders), as hard links (or copies where linking isn't possible). This runs only with `--flat_export`, which the CAVATICA app turns on; local runs and tests keep only nf-core's layout. CAVATICA publishes only that folder (the `riboseq_results` output in `sb_nextflow_schema.yaml`); everything else stays inside the task and is not saved to the project. Re-run the pipeline if it is needed.

- A failed run exports nothing.
- An export rule that matches nothing is skipped, because some outputs exist only for some runs (for example, translational efficiency needs contrasts).
- If two files would get the same exported name, the second is logged as an error and not exported.
- Nextflow's execution report, timeline, trace and DAG are written after the completion handler, so they are not exported; CAVATICA's task logs cover the same information.

## Naming

Each run is one task for the whole cohort. Set `output_basename` (`--outdir`) to the CAVATICA project name; CAVATICA task creation appends the task ID. Every exported file is named:

```text
<output_basename>_<CAVATICA_TASK_ID>_<tag><file name>
```

- Per-sample files keep their samplesheet name after the prefix (put the BA ID in the samplesheet's `sample` column), e.g. `<prefix>_<BA_ID>.genome.sorted.cram`.
- `<tag>` is added where file names alone would be unclear or would collide: `te_<method>_` and `te_orf_<method>_` for translational-efficiency results (gene-level and ORF-level anota2seq write the same file names), `cram_reference_`, `inframe_psite_` and `ribotish_`.

## Exported files

| Source in `outdir`                                        | Exported as (after the prefix)                                  | Why                                                                                      |
| --------------------------------------------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `alignment/star/sorted/*.sorted.cram` (+ `.crai`)         | `<sample>.{genome,transcriptome}.sorted.cram`                   | Genome and transcriptome alignments                                                      |
| `genome/cram_reference/genome.reference.sha256`           | `cram_reference_genome.reference.sha256`                        | Checksum of the genome FASTA the CRAMs were made with (the FASTA itself is not exported) |
| `genome/cram_reference/transcriptome.*`                   | `cram_reference_transcriptome.*`                                | Transcriptome FASTA, built from the run's GTF, needed to read the transcriptome CRAMs    |
| `multiqc/<aligner>/multiqc_report.html`                   | `multiqc_report.html`                                           | QC report (self-contained HTML)                                                          |
| `coverage/*.bigWig`                                       | `<sample>.{forward,reverse,unstranded}.bigWig`                  | Tracks for IGV or the UCSC genome browser                                                |
| `psites/ribowaltz/ribowaltz_qc/*`                         | `<sample>.ribowaltz.*`                                          | P-site QC plots and summary tables                                                       |
| `quantification/salmon/salmon.merged.*`                   | `salmon.merged.*`                                               | Gene and transcript counts, TPM and lengths, plus the SummarizedExperiment RDS files     |
| `quantification/inframe_psite/gene_counts.tsv`            | `inframe_psite_gene_counts.tsv`                                 | In-frame P-site gene counts                                                              |
| `quantification/orf_level/orf_psite_counts.tsv`           | `orf_psite_counts.tsv`                                          | ORF count matrix                                                                         |
| `orf_predictions/catalogue/**`                            | `cohort.catalogue.*`, `cohort_orfs.tsv`, `<sample>_orfs.tsv`, … | ORF catalogue, consensus and summary tables                                              |
| `orf_predictions/ribotish_all/allsamples_*`               | `ribotish_allsamples_*`                                         | Joint Ribo-TISH predictions                                                              |
| `translational_efficiency/<method>/*.{tsv,rds}`           | `te_<method>_…`                                                 | Gene-level TE results with gene symbols                                                  |
| `translational_efficiency/orf_level/**`                   | `te_orf_…`                                                      | ORF-level TE results and combined counts                                                 |
| `transcript_assembly/stringtie/stringtie_merge*.gtf`      | `stringtie_merge*.gtf`                                          | Merged transcript models that the ORF catalogue refers to                                |
| `pipeline_info/nf_core_riboseq_software_mqc_versions.yml` | same name                                                       | Software versions used                                                                   |
| `pipeline_info/params_<timestamp>.json`                   | same name                                                       | All run parameters, to reproduce the run                                                 |

RDS files are exported only for genuine R objects (SummarizedExperiment, DESeqDataSet, Anota2seq, DOTSeq). Each has TSV tables beside it for readers who don't use R.

## Alignments

All saved alignments are CRAM (`alignment_output_format = 'cram'`). BAMs exist only temporarily inside a run.

- Genome and transcriptome alignments are both saved as CRAM, so P-site and quantification steps can be re-run without realigning.
- A CRAM can only be read with the reference it was made with. The transcriptome FASTA is built from the run's GTF, so it is exported with every run. The genome FASTA is the standard reference given as `--fasta`: only its checksum is exported, and the run's params JSON records which FASTA was used.

## Not saved

| Output                                                                        | Why                                                                           |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Intermediate alignment BAMs                                                   | `save_align_intermeds = false`. In CRAM mode only CRAMs are published anyway. |
| `genome/` (indexes, sortmerna, FASTA copies), except `genome/cram_reference/` | Rebuilt from the reference (`save_reference = false`).                        |
| `orf_predictions/ribocode/annotation/`                                        | Rebuilt from the reference; identical across runs that use the same genome.   |

## Not published (kept only inside the task)

- `preprocessing/` (trimming, rRNA removal, FastQC, read-length statistics), summarized in MultiQC
- MultiQC's `multiqc_data/` and plot folders
- The genome FASTA copy in `genome/cram_reference/` (about 3 GB)
- `alignment/*/log/`, `samtools_stats/`, `picard_metrics/`
- Hybrid-STAR alignments and their reference (`alignment/hybrid_star/`, `genome/cram_reference/hybrid_transcriptome.*`), produced only with `extended_orf_analysis`
- Per-tool ORF predictions (`orf_predictions/ribotish/`, `ribocode/`, `ribotricer/`, `price/`, `rpbp/`)
- The per-read riboWaltz P-site tables, `psites/plastid/`, and `riboseq_qc/`
- The per-sample StringTie GTFs and `gffcompare/`
- Translational-efficiency plots
- Nextflow's execution report, timeline, trace and DAG

## Merging across samples

Merging happens inside a single run, over the samplesheet: the Salmon merge, the ORF count matrix, the ORF consensus, and the translational-efficiency contrasts. There is no separate merge workflow. When new samples arrive, the whole cohort is re-run.

### Alternative for discussion: separate per-sample and cohort stages

The pipeline could instead be split into two workflows:

1. A **per-sample** workflow (trimming, rRNA removal, alignment, P-site calling, per-sample quantification), run once per sample as it arrives.
2. A **cohort** workflow that takes the per-sample outputs and runs the Salmon merge, joint ORF calling, the ORF consensus and count matrix, and the translational-efficiency contrasts.

**For:** new samples don't require realigning old ones, and cohort-level analysis can be re-run cheaply with different contrasts.

**Against:**

- It diverges substantially from upstream nf-core/riboseq, making merges harder.
- Joint ORF calling (Ribo-TISH `allsamples_*`) and the ORF consensus depend on all samples, so the cohort stage remains the expensive part.
- It needs a new CAVATICA app and a merge ticket.

## Versioning

Releases are tagged `<upstream version>-cnh.<N>`: `2.0.0-cnh.1` is the fork's first release, based on nf-core/riboseq 2.0.0. `N` increases for each fork release on the same upstream version and restarts at 1 after syncing a new upstream release. This differs from the `vMAJOR.MINOR.PATCH` tags of other childrens-bti repositories because this repository also carries upstream's tags (`1.0.0`–`2.0.0`), and the suffix shows which upstream release a fork release is based on. `manifest.version` in `nextflow.config` stays at the upstream version so nf-core tooling and upstream merges keep working. Containers are pinned per module, as is standard for nf-core.
