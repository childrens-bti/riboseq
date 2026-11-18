#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 migration-manifest.tsv" >&2
    echo "Manifest columns: bam<TAB>bam_index<TAB>cram<TAB>reference_fasta" >&2
    exit 2
fi

manifest=$1
[[ -f "$manifest" ]] || { echo "Manifest not found: $manifest" >&2; exit 2; }
command -v samtools >/dev/null || { echo "samtools is required" >&2; exit 2; }
threads=${SAMTOOLS_THREADS:-8}

declare -a bams=()
declare -a indices=()
declare -a crams=()
declare -a references=()
declare -a generated=()

cleanup_on_error() {
    status=$?
    if [[ $status -ne 0 ]]; then
        for output in "${generated[@]}"; do
            rm -f -- "$output" "$output.crai"
        done
    fi
    exit "$status"
}
trap cleanup_on_error EXIT

while IFS=$'\t' read -r bam bam_index cram reference; do
    [[ -z "${bam:-}" || "${bam:0:1}" == "#" ]] && continue
    [[ -n "${bam_index:-}" && -n "${cram:-}" && -n "${reference:-}" ]] || {
        echo "Malformed manifest row; expected four tab-separated columns" >&2
        exit 2
    }
    [[ -f "$bam" ]] || { echo "Missing BAM: $bam" >&2; exit 1; }
    [[ -f "$bam_index" ]] || { echo "Missing BAM index: $bam_index" >&2; exit 1; }
    [[ -f "$reference" ]] || { echo "Missing reference FASTA: $reference" >&2; exit 1; }
    [[ ! -e "$cram" && ! -e "$cram.crai" ]] || { echo "Refusing to overwrite CRAM: $cram" >&2; exit 1; }
    bams+=("$bam")
    indices+=("$bam_index")
    crams+=("$cram")
    references+=("$reference")
done < "$manifest"

[[ ${#bams[@]} -gt 0 ]] || { echo "Manifest contains no migration rows" >&2; exit 2; }

for i in "${!bams[@]}"; do
    bam=${bams[$i]}
    cram=${crams[$i]}
    reference=${references[$i]}
    mkdir -p -- "$(dirname "$cram")"
    tmp_cram=$(mktemp --suffix=.cram "${cram}.tmp.XXXXXX")
    rm -f -- "$tmp_cram"
    generated+=("$tmp_cram")

    samtools quickcheck -v "$bam"
    samtools faidx "$reference"
    samtools view --no-PG -C -T "$reference" --threads "$threads" -o "$tmp_cram" "$bam"
    samtools index -@ "$threads" "$tmp_cram" "${tmp_cram}.crai"
    samtools quickcheck -v "$tmp_cram"

    samtools view -H "$bam" | awk '$1 == "@SQ" { print $2 "\t" $3 }' | sort > "${tmp_cram}.bam.sq"
    samtools view -H -T "$reference" "$tmp_cram" | awk '$1 == "@SQ" { print $2 "\t" $3 }' | sort > "${tmp_cram}.cram.sq"
    diff -u "${tmp_cram}.bam.sq" "${tmp_cram}.cram.sq"

    for flag in total mapped unmapped primary secondary supplementary; do
        case "$flag" in
            total) bam_count=$(samtools view -@ "$threads" -c "$bam"); cram_count=$(samtools view -@ "$threads" -c -T "$reference" "$tmp_cram") ;;
            mapped) bam_count=$(samtools view -@ "$threads" -c -F 4 "$bam"); cram_count=$(samtools view -@ "$threads" -c -F 4 -T "$reference" "$tmp_cram") ;;
            unmapped) bam_count=$(samtools view -@ "$threads" -c -f 4 "$bam"); cram_count=$(samtools view -@ "$threads" -c -f 4 -T "$reference" "$tmp_cram") ;;
            primary) bam_count=$(samtools view -@ "$threads" -c -F 2304 "$bam"); cram_count=$(samtools view -@ "$threads" -c -F 2304 -T "$reference" "$tmp_cram") ;;
            secondary) bam_count=$(samtools view -@ "$threads" -c -f 256 "$bam"); cram_count=$(samtools view -@ "$threads" -c -f 256 -T "$reference" "$tmp_cram") ;;
            supplementary) bam_count=$(samtools view -@ "$threads" -c -f 2048 "$bam"); cram_count=$(samtools view -@ "$threads" -c -f 2048 -T "$reference" "$tmp_cram") ;;
        esac
        [[ "$bam_count" == "$cram_count" ]] || { echo "$flag count mismatch for $bam" >&2; exit 1; }
    done

    bam_checksum=$(samtools view -@ "$threads" --no-PG "$bam" | sha256sum | cut -d' ' -f1)
    cram_checksum=$(samtools view -@ "$threads" --no-PG -T "$reference" "$tmp_cram" | sha256sum | cut -d' ' -f1)
    [[ "$bam_checksum" == "$cram_checksum" ]] || { echo "Decoded SAM checksum mismatch for $bam" >&2; exit 1; }

    mv -- "$tmp_cram" "$cram"
    mv -- "${tmp_cram}.crai" "${cram}.crai"
    rm -f -- "${tmp_cram}.bam.sq" "${tmp_cram}.cram.sq"
done

for bam in "${bams[@]}"; do rm -f -- "$bam"; done
for bam_index in "${indices[@]}"; do rm -f -- "$bam_index"; done

trap - EXIT
echo "Validated ${#bams[@]} BAM-to-CRAM conversions and removed the listed BAMs and indices."
