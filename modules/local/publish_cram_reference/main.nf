process PUBLISH_CRAM_REFERENCE {
    tag "${task.ext.prefix ?: 'reference'}"
    label 'process_low'

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c5d2818c8b9f58e1fba77ce219fdaf32087ae53e857c4a496402978af26e78c/data'
        : 'community.wave.seqera.io/library/htslib_samtools:1.23.1--5b6bb4ede7e612e5'}"

    input:
    path fasta

    output:
    path "${prefix}.fasta", emit: fasta
    path "${prefix}.fasta.fai", emit: fai
    path "${prefix}.reference.sha256", emit: checksum
    tuple val("${task.process}"), val('samtools'), eval('samtools version | sed "1!d;s/.* //"'), emit: versions_samtools, topic: versions

    script:
    prefix = task.ext.prefix ?: 'reference'
    """
    if [[ "${fasta}" != "${prefix}.fasta" ]]; then
        cp "${fasta}" "${prefix}.fasta"
    fi
    samtools faidx ${prefix}.fasta
    sha256sum ${prefix}.fasta ${prefix}.fasta.fai > ${prefix}.reference.sha256
    """

    stub:
    prefix = task.ext.prefix ?: 'reference'
    """
    touch ${prefix}.fasta ${prefix}.fasta.fai ${prefix}.reference.sha256
    """
}
