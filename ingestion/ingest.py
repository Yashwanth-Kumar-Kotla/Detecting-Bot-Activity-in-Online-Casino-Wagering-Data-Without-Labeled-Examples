"""Check the input files and register them in a local DuckDB catalog."""
import argparse
from pathlib import Path

import duckdb

INPUTS = {
    "wagers": ("patron_wagers_all.parquet", "read_parquet",
               {"member", "game", "date", "tableNO", "shoe_ref", "shoe_hand", "shoe_ID",
                "min_time_stamp", "primary_bet", "boxes", "bet", "wl", "theo", "prop_bet", "operator"}),
    "scores": ("baccarat_hand_scores.parquet", "read_parquet",
               {"game", "date", "tableNO", "shoe_ref", "shoe_hand", "bank_beta", "plyr_beta"}),
    "rebates": ("rebate_summary.csv", "read_csv_auto", {"member", "avg_rebate_pcnt"}),
}


def ingest(data_dir, database):
    for filename, _, _ in INPUTS.values():
        if not (data_dir / filename).is_file():
            raise FileNotFoundError(f"Missing input: {filename}")

    database.parent.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(database)) as con:
        con.execute("BEGIN")
        for view, (filename, reader, required) in INPUTS.items():
            path = str((data_dir / filename).resolve()).replace("'", "''")
            source = f"{reader}('{path}')"
            if view == "rebates":
                source = source[:-1] + ", types={'member': 'VARCHAR'})"
            columns = {row[0] for row in con.sql(f"DESCRIBE SELECT * FROM {source}").fetchall()}
            if missing := required - columns:
                raise ValueError(f"{filename} is missing columns: {', '.join(sorted(missing))}")
            con.execute(f"CREATE OR REPLACE VIEW {view} AS SELECT * FROM {source}")
            count = con.sql(f"SELECT count(*) FROM {view}").fetchone()[0]
            if not count:
                raise ValueError(f"{filename} is empty")
            print(f"{filename}: {count:,} rows")
        con.execute("COMMIT")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path, help="Folder containing the three Drive downloads")
    parser.add_argument("--database", type=Path, default=Path("private/wagers.duckdb"))
    args = parser.parse_args()
    ingest(args.data_dir, args.database)
