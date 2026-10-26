#!/usr/bin/env python3
"""Write annotated, compact cohort and per-sample ORF consensus tables."""

import argparse
import csv
import gzip
import shlex
from collections import defaultdict
from pathlib import Path


CALLERS = ("ribotish", "ribocode", "ribotricer", "rpbp", "price")
OUTPUT_COLUMNS = (
    "orf_id",
    "gene_id",
    "gene_symbol",
    "transcript_id",
    "transcript_name",
    "n_host_genes",
    "n_host_transcripts",
    "orf_class",
    "aa_length",
    "is_smorf",
    "chrom",
    "start",
    "end",
    "strand",
    "cohort_n_callers",
    "cohort_callers",
    "cohort_n_samples",
    "cohort_samples",
)


def read_tsv(path, required):
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        missing = set(required) - set(reader.fieldnames or ())
        if missing:
            raise ValueError(f"{path}: missing columns: {', '.join(sorted(missing))}")
        return list(reader)


def gtf_attributes(field):
    lexer = shlex.shlex(field, posix=True)
    lexer.whitespace = ";"
    lexer.whitespace_split = True
    lexer.commenters = ""
    attributes = {}
    for entry in lexer:
        pair = entry.strip().split(None, 1)
        if len(pair) == 2:
            attributes[pair[0]] = pair[1]
    return attributes


def annotation_names(gtf_path, gene_ids, transcript_ids):
    gene_names = {}
    transcript_names = {}

    def remember(names, requested, identifier, name):
        if identifier not in requested or not name:
            return
        if identifier in names and names[identifier] != name:
            raise ValueError(f"{gtf_path}: conflicting names for {identifier}")
        names[identifier] = name

    opener = gzip.open if str(gtf_path).endswith(".gz") else open
    with opener(gtf_path, "rt") as handle:
        for line in handle:
            if line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 9 or fields[2] not in ("gene", "transcript"):
                continue
            attributes = gtf_attributes(fields[8])
            remember(gene_names, gene_ids, attributes.get("gene_id"), attributes.get("gene_name"))
            if fields[2] == "transcript":
                remember(
                    transcript_names,
                    transcript_ids,
                    attributes.get("transcript_id"),
                    attributes.get("transcript_name"),
                )
    return gene_names, transcript_names


def riboseq_samples(samplesheet):
    with open(samplesheet, newline="") as handle:
        reader = csv.DictReader(handle)
        missing = {"sample", "type"} - set(reader.fieldnames or ())
        if missing:
            raise ValueError(f"{samplesheet}: missing columns: {', '.join(sorted(missing))}")
        rows = list(reader)
    samples = sorted({row["sample"] for row in rows if row["type"] == "riboseq"})
    for sample in samples:
        if not sample or "/" in sample or "\\" in sample or sample in (".", ".."):
            raise ValueError(f"{samplesheet}: unsafe sample ID: {sample!r}")
    return samples


def write_tsv(path, rows):
    with open(path, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_COLUMNS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def export(consensus_path, mapping_path, gtf_path, samplesheet_path, outdir):
    required = {
        "orf_id", "gene_id", "transcript_id", "orf_class", "aa_length", "is_smorf",
        "chrom", "start", "end", "strand", "n_samples", "samples",
    }
    required.update(f"called_by_{caller}" for caller in CALLERS)
    consensus = read_tsv(consensus_path, required)
    mappings = read_tsv(mapping_path, ("orf_id", "gene_id", "transcript_id"))
    samples = riboseq_samples(samplesheet_path)

    if len({row["orf_id"] for row in consensus}) != len(consensus):
        raise ValueError(f"{consensus_path}: duplicate orf_id")

    host_genes = defaultdict(set)
    host_transcripts = defaultdict(set)
    for row in mappings:
        if row["gene_id"]:
            host_genes[row["orf_id"]].add(row["gene_id"])
        if row["transcript_id"]:
            host_transcripts[row["orf_id"]].add(row["transcript_id"])

    gene_names, transcript_names = annotation_names(
        gtf_path,
        {row["gene_id"] for row in consensus},
        {row["transcript_id"] for row in consensus},
    )

    summary = []
    memberships = []
    for row in consensus:
        orf_id = row["orf_id"]
        genes = host_genes[orf_id]
        transcripts = host_transcripts[orf_id]
        if row["gene_id"] not in genes or row["transcript_id"] not in transcripts:
            raise ValueError(f"{mapping_path}: representative mapping missing for {orf_id}")
        flags = {caller: row[f"called_by_{caller}"] for caller in CALLERS}
        if set(flags.values()) - {"0", "1"}:
            raise ValueError(f"{consensus_path}: invalid caller flag for {orf_id}")
        callers = [caller for caller in CALLERS if flags[caller] == "1"]
        contributing_samples = {sample for sample in row["samples"].split(",") if sample}
        if len(contributing_samples) != int(row["n_samples"]):
            raise ValueError(f"{consensus_path}: n_samples disagrees with samples for {orf_id}")
        summary.append({
            "orf_id": orf_id,
            "gene_id": row["gene_id"],
            "gene_symbol": gene_names.get(row["gene_id"], ""),
            "transcript_id": row["transcript_id"],
            "transcript_name": transcript_names.get(row["transcript_id"], ""),
            "n_host_genes": len(genes),
            "n_host_transcripts": len(transcripts),
            "orf_class": row["orf_class"],
            "aa_length": row["aa_length"],
            "is_smorf": row["is_smorf"],
            "chrom": row["chrom"],
            "start": row["start"],
            "end": row["end"],
            "strand": row["strand"],
            "cohort_n_callers": len(callers),
            "cohort_callers": ",".join(callers),
            "cohort_n_samples": row["n_samples"],
            "cohort_samples": row["samples"],
        })
        memberships.append(contributing_samples)

    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    write_tsv(outdir / "cohort_orfs.tsv", summary)
    for sample in samples:
        sample_rows = [row for row, members in zip(summary, memberships) if sample in members]
        write_tsv(outdir / f"sample_{sample}_orfs.tsv", sample_rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--consensus", required=True, type=Path)
    parser.add_argument("--mapping", required=True, type=Path)
    parser.add_argument("--gtf", required=True, type=Path)
    parser.add_argument("--samplesheet", required=True, type=Path)
    parser.add_argument("--outdir", default=Path("."), type=Path)
    args = parser.parse_args()
    export(args.consensus, args.mapping, args.gtf, args.samplesheet, args.outdir)


if __name__ == "__main__":
    main()
