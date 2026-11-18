process ORF_CONSENSUS_SUMMARY {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0f/0f1019bd22c111267bcb670fdb128829776f0ca6adfa7b0e2d126f91577d08e3/data' :
        'community.wave.seqera.io/library/python_pandas_pyyaml:75514f9f977be607' }"

    input:
    tuple val(meta), path(consensus_tsv), path(orf_to_gene_tsv)
    path gtf
    path samplesheet

    output:
    tuple val(meta), path("cohort_orfs.tsv")   , emit: cohort
    tuple val(meta), path("sample_*_orfs.tsv", optional: true), emit: samples

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python ${projectDir}/bin/orf_consensus_summary.py \
        --consensus ${consensus_tsv} \
        --mapping ${orf_to_gene_tsv} \
        --gtf ${gtf} \
        --samplesheet ${samplesheet}
    """

    stub:
    """
    python - <<'PY'
import csv
from pathlib import Path

Path('cohort_orfs.tsv').write_text('orf_id\\n')
with open('${samplesheet}', newline='') as handle:
    samples = {row['sample'] for row in csv.DictReader(handle) if row['type'] == 'riboseq'}
for sample in samples:
    Path(f'sample_{sample}_orfs.tsv').write_text('orf_id\\n')
PY
    """
}
