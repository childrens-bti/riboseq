process BAM_TO_CRAM {
    tag "${meta.id}"
    label 'process_medium'

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c5d2818c8b9f58e1fba77ce219fdaf32087ae53e857c4a496402978af26e78c/data'
        : 'community.wave.seqera.io/library/htslib_samtools:1.23.1--5b6bb4ede7e612e5'}"

    input:
    tuple val(meta), path(bam)
    path fasta

    output:
    tuple val(meta), path("${prefix}.cram"), path("${prefix}.cram.crai"), emit: cram
    tuple val("${task.process}"), val('samtools'), eval('samtools version | sed "1!d;s/.* //"'), emit: versions_samtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}.sorted"
    """
    samtools quickcheck -v ${bam}
    samtools faidx ${fasta}
    samtools view --no-PG -C -T ${fasta} --threads ${task.cpus - 1} -o ${prefix}.cram ${bam}
    samtools index -@ ${task.cpus - 1} ${prefix}.cram ${prefix}.cram.crai
    samtools quickcheck -v ${prefix}.cram
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}.sorted"
    """
    touch ${prefix}.cram ${prefix}.cram.crai
    """
}
