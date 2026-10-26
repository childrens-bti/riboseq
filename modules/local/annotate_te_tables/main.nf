process ANNOTATE_TE_TABLES {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0f/0f1019bd22c111267bcb670fdb128829776f0ca6adfa7b0e2d126f91577d08e3/data' :
        'community.wave.seqera.io/library/python_pandas_pyyaml:75514f9f977be607' }"

    input:
    tuple val(meta), path(tables, stageAs: 'input/*'), path(orf_to_gene)
    path gtf

    output:
    tuple val(meta), path("annotated/*.tsv"), emit: tables

    when:
    task.ext.when == null || task.ext.when

    script:
    def orf_to_gene_arg = orf_to_gene ? "--orf-to-gene ${orf_to_gene}" : ''
    """
    python ${projectDir}/bin/annotate_te_tables.py \\
        --gtf ${gtf} \\
        ${orf_to_gene_arg} \\
        --outdir annotated \\
        ${tables}
    """

    stub:
    """
    mkdir -p annotated
    for table in ${tables}; do
        cp "\$table" annotated/
    done
    """
}
