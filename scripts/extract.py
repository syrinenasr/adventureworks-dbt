"""Export the AdventureWorksDW2022 tables used by the dbt project to Parquet.

The tables are treated as the raw layer of a source system. The script only
runs SELECT statements and writes one Parquet file per table to data/raw/.

Connection settings come from environment variables:
    APP_DB_PASSWORD  password of the read-only login (required)
    MSSQL_SERVER     default "localhost,1433"
    MSSQL_DATABASE   default "AdventureWorksDW2022"
    MSSQL_USER       default "askl_reader"

Run:
    uv run --group extract --env-file /path/to/.env python scripts/extract.py
"""

from __future__ import annotations

import os
from pathlib import Path

import mssql_python
import pyarrow as pa
import pyarrow.parquet as pq

OUT_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"

TABLES = [
    "FactInternetSales",
    "FactResellerSales",
    "DimDate",
    "DimCustomer",
    "DimGeography",
    "DimProduct",
    "DimProductSubcategory",
    "DimProductCategory",
    "DimSalesTerritory",
    "DimPromotion",
    "DimCurrency",
    "DimReseller",
]

# Columns left out to keep the files small: images and translations
# that no model uses.
SKIP_TYPES = {"varbinary", "image"}
SKIP_PREFIXES = ("Spanish", "French", "Chinese", "Arabic", "Hebrew", "Thai", "German", "Japanese", "Turkish")

DECIMAL_TYPES = {"money": pa.decimal128(19, 4), "smallmoney": pa.decimal128(10, 4)}
ARROW_TYPES = {
    "bigint": pa.int64(),
    "int": pa.int32(),
    "smallint": pa.int16(),
    "tinyint": pa.int16(),
    "bit": pa.bool_(),
    "float": pa.float64(),
    "real": pa.float32(),
    "date": pa.date32(),
    "datetime": pa.timestamp("us"),
    "datetime2": pa.timestamp("us"),
    "nvarchar": pa.string(),
    "nchar": pa.string(),
    "varchar": pa.string(),
    "char": pa.string(),
    **DECIMAL_TYPES,
}


def connect() -> mssql_python.Connection:
    server = os.environ.get("MSSQL_SERVER", "localhost,1433")
    database = os.environ.get("MSSQL_DATABASE", "AdventureWorksDW2022")
    user = os.environ.get("MSSQL_USER", "askl_reader")
    password = os.environ["APP_DB_PASSWORD"]
    return mssql_python.connect(
        f"Server={server};Database={database};UID={user};PWD={password};"
        "Encrypt=yes;TrustServerCertificate=yes"
    )


def table_columns(cursor, table: str) -> list[tuple[str, str]]:
    cursor.execute(
        "select column_name, data_type from information_schema.columns "
        "where table_schema = 'dbo' and table_name = ? order by ordinal_position",
        (table,),
    )
    return [
        (name, dtype)
        for name, dtype in cursor.fetchall()
        if dtype not in SKIP_TYPES and not name.startswith(SKIP_PREFIXES)
    ]


def export_table(cursor, table: str) -> int:
    columns = table_columns(cursor, table)
    schema = pa.schema([(name, ARROW_TYPES[dtype]) for name, dtype in columns])
    select_list = ", ".join(f"[{name}]" for name, _ in columns)
    order_by = ", ".join(f"[{name}]" for name, _ in columns[:2])
    cursor.execute(f"select {select_list} from dbo.[{table}] order by {order_by}")
    rows = cursor.fetchall()
    data = {name: [row[i] for row in rows] for i, (name, _) in enumerate(columns)}
    arrow_table = pa.table(data, schema=schema)
    pq.write_table(arrow_table, OUT_DIR / f"{table}.parquet", compression="zstd")
    return arrow_table.num_rows


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with connect() as conn:
        cursor = conn.cursor()
        for table in TABLES:
            n_rows = export_table(cursor, table)
            size_kb = (OUT_DIR / f"{table}.parquet").stat().st_size / 1024
            print(f"{table:<24} {n_rows:>7} rows  {size_kb:>8.1f} KB")


if __name__ == "__main__":
    main()
