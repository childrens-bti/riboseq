#!/usr/bin/env python3
"""Add gene symbols to translational-efficiency result tables.

Each table's first column holds the feature identifier. Gene-level tables
gain a ``gene_symbol`` column after it. ORF-level tables (identifiers found in
the ORF-to-gene mapping) gain ``host_gene_id`` and ``gene_symbol``; ORFs with
several host genes list them ``;``-separated, in matching order.
"""

import argparse
import csv
from pathlib import Path

from orf_consensus_summary import annotation_names


def read_orf_hosts(path):
    hosts = {}
    with open(path, newline="") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            genes = hosts.setdefault(row["orf_id"], [])
            if row["gene_id"] not in genes:
                genes.append(row["gene_id"])
    return hosts


def read_table(table, orf_hosts):
    with open(table, newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        header = next(reader, None)
        rows = [row for row in reader if row]

    ids = [row[0] for row in rows]
    is_orf = bool(orf_hosts) and any(feature_id in orf_hosts for feature_id in ids)
    host_genes = {feature_id: orf_hosts.get(feature_id, []) if is_orf else [feature_id] for feature_id in ids}
    return header, rows, is_orf, host_genes


def annotate(table, out_path, gene_names, parsed):
    header, rows, is_orf, host_genes = parsed
    if not header:
        Path(out_path).write_text(Path(table).read_text())
        return

    extra = ["host_gene_id", "gene_symbol"] if is_orf else ["gene_symbol"]
    with open(out_path, "w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(header[:1] + extra + header[1:])
        for row in rows:
            genes = host_genes[row[0]]
            symbols = ";".join(gene_names.get(gene, "") for gene in genes)
            values = [";".join(genes), symbols] if is_orf else [symbols]
            writer.writerow(row[:1] + values + row[1:])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gtf", required=True, help="Reference GTF with gene_name attributes")
    parser.add_argument("--orf-to-gene", help="ORF-to-host mapping (orf_id, gene_id, transcript_id)")
    parser.add_argument("--outdir", default="annotated", help="Directory for the annotated tables")
    parser.add_argument("tables", nargs="+", help="Result TSVs whose first column is a gene or ORF id")
    args = parser.parse_args()

    orf_hosts = read_orf_hosts(args.orf_to_gene) if args.orf_to_gene else {}
    parsed = {table: read_table(table, orf_hosts) for table in args.tables}

    # One pass over the GTF covers every table
    gene_ids = {gene for _, _, _, hosts in parsed.values() for genes in hosts.values() for gene in genes}
    gene_names, _ = annotation_names(args.gtf, gene_ids, set())

    Path(args.outdir).mkdir(exist_ok=True)
    for table in args.tables:
        annotate(table, Path(args.outdir) / Path(table).name, gene_names, parsed[table])


if __name__ == "__main__":
    main()
