"""Load the raw Parquet files in data/raw/ into Snowflake.

NOT TESTED: this script was written without access to a Snowflake account.
It follows the documented PUT / INFER_SCHEMA / COPY INTO pattern.

For each Parquet file it:
  1. uploads the file to an internal stage (PUT),
  2. creates the table from the file's schema (INFER_SCHEMA), with column
     names upper-cased so that unquoted identifiers in the dbt models match,
  3. loads the rows (COPY INTO ... MATCH_BY_COLUMN_NAME).

Uses the same environment variables as the `snowflake` target in
profiles.yml (SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD,
SNOWFLAKE_ROLE, SNOWFLAKE_WAREHOUSE, SNOWFLAKE_DATABASE) plus
ADVENTUREWORKS_RAW_SCHEMA (default RAW).

Run:
    uv run python scripts/load_snowflake.py
"""

from __future__ import annotations

import os
from pathlib import Path

import snowflake.connector

RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"


def main() -> None:
    raw_schema = os.environ.get("ADVENTUREWORKS_RAW_SCHEMA", "raw")
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ["SNOWFLAKE_ROLE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
    )
    try:
        cur = conn.cursor()
        cur.execute(f"create schema if not exists {raw_schema}")
        cur.execute(f"use schema {raw_schema}")
        cur.execute(
            "create or replace file format parquet_format "
            "type = parquet use_logical_type = true"
        )
        cur.execute("create or replace stage raw_stage file_format = parquet_format")

        for path in sorted(RAW_DIR.glob("*.parquet")):
            table = path.stem
            stage_path = f"@raw_stage/{table}/"
            cur.execute(
                f"put 'file://{path.as_posix()}' {stage_path} "
                "auto_compress = false overwrite = true"
            )
            cur.execute(
                f"""
                create or replace table {table} using template (
                    select array_agg(
                        object_construct(
                            'COLUMN_NAME', upper(column_name),
                            'TYPE', type,
                            'NULLABLE', nullable
                        )
                    ) within group (order by order_id)
                    from table(
                        infer_schema(
                            location => '{stage_path}',
                            file_format => 'parquet_format'
                        )
                    )
                )
                """
            )
            cur.execute(
                f"""
                copy into {table}
                from {stage_path}
                file_format = (format_name = 'parquet_format')
                match_by_column_name = case_insensitive
                """
            )
            cur.execute(f"select count(*) from {table}")
            print(f"{table:<24} {cur.fetchone()[0]:>7} rows")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
