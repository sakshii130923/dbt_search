#!/usr/bin/env python
"""Build a raw->canonical village mapping using fuzzy matching.

Usage example from project root:

    .venv/bin/python scripts/generate_village_mapping.py \
        --db-connection "dbname=foo user=bar host=..." \
        --table schema.source_table --column village_col

The script will read the canonical list from ``seeds/villages.csv`` by default
and emit ``seeds/village_mapping.csv`` (raw_name,canonical_name pairs).
Existing mapping entries are overwritten.

For convenience you can point ``--canonical`` or ``--out`` at other paths.
"""
import argparse
import csv
import psycopg2
from rapidfuzz import process, fuzz
import sys


def load_canonical(path):
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return [row['village_name'] for row in reader]


def get_raw_values(conn, table, column):
    sql = f"select distinct {column} from {table} where {column} is not null"
    with conn.cursor() as cur:
        cur.execute(sql)
        return [row[0] for row in cur.fetchall()]


def load_raw_from_csv(path, column_name=None):
    """Load raw village values from a CSV file.

    If the CSV has a header row that contains `column_name`, that column
    will be used. Otherwise the first column is used as the raw value.
    """
    values = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        headers = next(reader, None)
        idx = None
        if column_name and headers:
            try:
                idx = headers.index(column_name)
            except ValueError:
                idx = None

        if idx is None:
            # Rewind and treat every row's first column as a raw value
            f.seek(0)
            reader = csv.reader(f)
            for row in reader:
                if row:
                    values.append(row[0])
        else:
            for row in reader:
                if len(row) > idx:
                    values.append(row[idx])
    return values


def generate_mapping(raw_list, canon_list, threshold=80):
    mapping = {}
    for r in set(raw_list):
        best = process.extractOne(r, canon_list, scorer=fuzz.token_sort_ratio)
        if best and best[1] >= threshold:
            mapping[r] = best[0]
        else:
            mapping[r] = r
    return mapping


def write_mapping(mapping, outpath):
    with open(outpath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['raw_name', 'canonical_name'])
        for r, c in sorted(mapping.items()):
            writer.writerow([r, c])


def main():
    parser = argparse.ArgumentParser(description="Generate village mapping CSV.")
    parser.add_argument('--db-connection', required=True,
                        help='Postgres connection string')
    parser.add_argument('--table', required=True,
                        help='qualified source table name to scan')
    parser.add_argument('--column', required=True,
                        help='column name containing village text')
    parser.add_argument('--raw-csv', required=False,
                        help='path to CSV file containing raw village values (one column or header). If provided, DB scanning is skipped.')
    parser.add_argument('--canonical', default='seeds/villages.csv',
                        help='path to canonical villages CSV')
    parser.add_argument('--out', default='seeds/village_mapping.csv',
                        help='output mapping CSV path')
    parser.add_argument('--threshold', type=int, default=80,
                        help='minimum fuzzy score to accept a match')
    args = parser.parse_args()

    canon = load_canonical(args.canonical)
    raw = None
    if args.raw_csv:
        raw = load_raw_from_csv(args.raw_csv, column_name=args.column)
    else:
        try:
            conn = psycopg2.connect(args.db_connection)
        except Exception as e:
            print(f"ERROR: cannot connect to database: {e}", file=sys.stderr)
            sys.exit(1)
        raw = get_raw_values(conn, args.table, args.column)
    mapping = generate_mapping(raw, canon, threshold=args.threshold)
    write_mapping(mapping, args.out)
    print(f"wrote {len(mapping)} mappings to {args.out}")


if __name__ == '__main__':
    main()
