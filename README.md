# adventureworks-dbt

A dbt project on Microsoft's AdventureWorksDW2022 sample data warehouse. The
warehouse tables are treated as the raw layer of a source system, and the
project models them into a tested star schema with a slowly changing product
dimension, an incremental sales fact and a MetricFlow semantic layer.

It runs end to end on DuckDB from Parquet files committed in this repository,
so it needs no database server. A `snowflake` target is included for running
the same models on Snowflake; that target has not been run (see
[Verified](#verified)).

## Lineage

```
data/raw/*.parquet  (12 tables; on Snowflake: tables in the RAW schema)
        |
        v
staging        stg_adventureworks__*  (12 views, one per source table)
        |
        v
intermediate   int_sales__unioned       internet + reseller lines, UNION ALL
               int_products__versioned  SCD type 2 validity ranges
        |
        v
marts          fct_sales (incremental)
               dim_product (SCD2)  dim_customer  dim_reseller
               dim_date  dim_territory  dim_promotion
               metricflow_time_spine
        |
        v
semantic layer 4 semantic models, 8 metrics (models/marts/_semantic_models.yml)

snapshots      snap_products (reads stg_adventureworks__products; nothing depends on it)
```

`dbt docs generate && dbt docs serve` shows the full graph.

## Layers

- **staging** (views, schema `*_staging`): one model per source table. Renames
  PascalCase columns to snake_case (`EnglishProductName` becomes
  `product_name`), casts datetimes that only carry a date to `date`, decodes
  single-letter codes, and drops columns nothing uses (photos, translations,
  customer contact details). No joins.
- **intermediate** (views, schema `*_intermediate`): logic that would
  otherwise be repeated or would clutter a mart.
  `int_sales__unioned` puts both sales channels into one shape;
  `int_products__versioned` rebuilds product validity ranges.
- **marts** (tables, schema `*_marts`): a star schema for analysis. One fact
  at order-line grain and six dimensions.

The source tables are declared in
`models/staging/adventureworks/_adventureworks__sources.yml`. On DuckDB, dbt
reads them straight from `data/raw/{table}.parquet` (the dbt-duckdb
`external_location` setting); other adapters ignore that setting and read the
tables from the raw schema. Source freshness is switched off because the
extract is static and has no load timestamp; the file says what a live setup
would use instead.

## Things the source gets wrong, and how the models handle them

These come from an earlier evaluation of LLM-written SQL on this database
and from profiling the data:

- **The two sales facts share no orders.** `FactInternetSales` and
  `FactResellerSales` are separate order streams. `fct_sales` stacks them with
  `UNION ALL` and a `channel` column; they are never joined. A singular test
  (`assert_no_order_in_both_channels`) fails if an order number appears in
  both channels.
- **A row is an order line, not an order.** Order count is
  `count(distinct sales_order_number)`. The semantic layer defines
  `order_count` and `order_line_count` as separate metrics.
- **Revenue is `SalesAmount`**, gross profit is
  `SalesAmount - TotalProductCost`. Both have one definition, in the semantic
  layer.
- **There is no `ProductName` column**; the name is `EnglishProductName`,
  renamed to `product_name` in staging.
- **`DimProduct` is a slowly changing dimension** (606 rows for 504
  products), and its `EndDate` is unusable: on all 200 history rows it is
  earlier than `StartDate`. See the next section.

## SCD type 2: `dim_product`

The source already keeps product history as rows: each cost/price release
(2011-07-01, 2012-07-01, 2013-07-01, plus 2003-07-01 for products that never
changed) adds a row with a new `ProductKey`. A dbt snapshot could only record
changes from the day it starts running, so it cannot recover this history.
`dim_product` is therefore built from the history rows in
`int_products__versioned`:

- `valid_from` = the version's `StartDate`;
- `valid_to` = the next version's `valid_from`; for the last version of a
  discontinued product, the next catalogue release date (the first release
  the product is missing from); null for the current version;
- `is_current` = source `Status = 'Current'`.

Ranges are half-open (`valid_from <= date < valid_to`). The facts carry the
version key (`product_key`), so a sale shows the product attributes that
applied when it was recorded, with no date-range join. 98 discontinued
products have no current row.

Checks: a dbt unit test (`test_product_validity_ranges`) covers the three
`valid_to` cases on fixed input rows; `dbt_utils.mutually_exclusive_ranges`
checks that a product's versions never overlap; the singular test
`assert_at_most_one_current_version_per_product` checks that a product has at
most one current version and that it is the latest one.

`snapshots/snap_products.yml` shows the other pattern, for sources that
overwrite rows in place: a `check` snapshot on cost, price and status, with
`hard_deletes: invalidate`. It is built and kept, but no model depends on it.

## Incremental model: `fct_sales`

`fct_sales` is incremental with the `delete+insert` strategy on
`sales_line_key` (a hash of channel, order number and line number). On each
run it re-reads the lines whose `order_date` is within
`var('sales_lookback_days')` days (default 3) of the latest loaded order
date, deletes those keys from the table and inserts them again. The lookback
picks up late or corrected lines. `delete+insert` works the same way on
dbt-duckdb and dbt-snowflake. Use `--full-refresh` to rebuild from scratch.
SQL that differs between dialects goes through dbt's cross-database macros
(`dbt.dateadd`, `dbt.datediff`, `dbt.date_trunc`, `dbt.concat`,
`dbt.type_int`, `dbt.type_numeric`).

## Tests

`dbt build` runs 118 data tests and 1 unit test:

- generic tests: `unique` and `not_null` on every primary key,
  `relationships` from each fact foreign key to its dimension,
  `accepted_values` on channel, gender, marital status, categories and
  similar code columns, conditional `not_null`
  (`customer_key` for Internet lines, `reseller_key` for Reseller lines);
- dbt_utils tests: `unique_combination_of_columns` on order number + line
  number, `expression_is_true` (positive quantities, non-negative revenue),
  `mutually_exclusive_ranges` on product versions;
- singular tests in `tests/` that encode business rules:
  - `assert_fct_sales_matches_source_totals`: per channel, `fct_sales` has
    the same number of order lines and orders, and the same revenue and
    product cost, as the source fact table;
  - `assert_no_order_in_both_channels`;
  - `assert_at_most_one_current_version_per_product`;
- unit test `test_product_validity_ranges` (see above).

## Semantic layer

`models/marts/_semantic_models.yml` defines MetricFlow semantic models on
`fct_sales`, `dim_product`, `dim_customer` and `dim_territory`, and one
governed definition per metric:

| metric | definition |
| --- | --- |
| `revenue` | sum of `sales_amount` |
| `total_product_cost` | sum of `total_product_cost` |
| `gross_profit` | sum of `sales_amount - total_product_cost` |
| `gross_margin` | `gross_profit / revenue` |
| `units_sold` | sum of `order_quantity` |
| `order_count` | count distinct `sales_order_number` |
| `order_line_count` | count of order lines |
| `average_order_value` | `revenue / order_count` |

Dashboards and other tools ask for `revenue by channel` instead of writing
their own SQL, so every consumer gets the same number. My other project,
AskL-Rose, applies the same idea to an LLM: it answers plain-English
questions on this database through a YAML semantic layer instead of letting
the model write free SQL.

Example on DuckDB (output of a local run, table rules removed):

```
$ uv run mf query --metrics revenue,gross_profit,gross_margin,order_count,order_line_count,units_sold,average_order_value \
    --group-by sales_line__channel --order sales_line__channel --decimals 4

sales_line__channel  revenue        gross_profit   order_count  order_line_count  units_sold  gross_margin  average_order_value
Internet             29358677.2207  12080883.6450        27659             60398       60398        0.4115            1061.4511
Reseller             80450596.9823    470482.6033         3796             60855      214378        0.0058           21193.5187
```

Revenue totals match `sum(SalesAmount)` of the two source tables in SQL
Server. Amounts are kept as stored in the source; each line also carries the
`currency_code` recorded in the source, and no currency conversion is
applied.

## Run it on DuckDB

Requires [uv](https://docs.astral.sh/uv/). Python 3.12 is installed by uv.

```
uv sync
uv run dbt deps
uv run dbt build
uv run dbt docs generate && uv run dbt docs serve
```

`dbt build` creates `adventureworks.duckdb` in the project directory. Other
commands:

```
uv run sqlfluff lint models tests        # SQL lint (dbt templater, duckdb dialect)
uv run mf validate-configs               # validate the semantic layer
uv run mf query --metrics revenue --group-by metric_time__year,product__product_category_name
```

`profiles.yml` is in the project root, so no `~/.dbt/profiles.yml` is needed.

## Run it on Snowflake (not tested)

1. Create a Snowflake trial account, a warehouse and a database.
2. Export the connection settings:

   ```
   export SNOWFLAKE_ACCOUNT=...    # e.g. xy12345.eu-central-1
   export SNOWFLAKE_USER=...
   export SNOWFLAKE_PASSWORD=...
   export SNOWFLAKE_ROLE=...       # e.g. ACCOUNTADMIN on a trial, or a dedicated role
   export SNOWFLAKE_WAREHOUSE=...
   export SNOWFLAKE_DATABASE=...
   export SNOWFLAKE_SCHEMA=ANALYTICS
   # optional, default RAW:
   export ADVENTUREWORKS_RAW_SCHEMA=RAW
   ```

3. Load the Parquet files into the raw schema. `scripts/load_snowflake.py`
   creates an internal stage, uploads each file with `PUT`, creates each
   table from the file's schema with `INFER_SCHEMA` (column names upper-cased
   so unquoted identifiers match), and loads it with `COPY INTO ...
   MATCH_BY_COLUMN_NAME`:

   ```
   uv run python scripts/load_snowflake.py
   ```

4. Build:

   ```
   uv run dbt build --target snowflake
   ```

Models land in `ANALYTICS_STAGING`, `ANALYTICS_INTERMEDIATE`,
`ANALYTICS_MARTS` and `ANALYTICS_SNAPSHOTS` (dbt's default schema naming).

## Refreshing the raw extract

The Parquet files were exported from a local SQL Server 2022 copy of
AdventureWorksDW2022 with a read-only login. To export them again:

```
uv sync --group extract
APP_DB_PASSWORD=... uv run python scripts/extract.py
```

`MSSQL_SERVER`, `MSSQL_DATABASE` and `MSSQL_USER` override the defaults
(`localhost,1433`, `AdventureWorksDW2022`, `askl_reader`). The script only
runs `SELECT` statements. The Parquet files total about 2.5 MB.

## CI

`.github/workflows/ci.yml` runs on pushes to `main` and on pull requests:
`uv sync --locked`, `dbt deps`, `sqlfluff lint`, `dbt build` on DuckDB from
the committed Parquet files, a second incremental `dbt build --select
fct_sales+`, `mf validate-configs` and `dbt docs generate`.

## Verified

Run locally on macOS (Apple Silicon) with Python 3.12, dbt-core 1.10.23,
dbt-duckdb 1.10.1, DuckDB 2.0.0, dbt-metricflow 0.13.0, sqlfluff 4.5.0:

- `scripts/extract.py` against SQL Server 2022: 12 tables exported.
- `dbt build` (DuckDB): PASS=142, ERROR=0 (22 models, 1 snapshot,
  118 data tests, 1 unit test).
- Incremental path: deleted the 1,970 `fct_sales` lines after 2013-12-31,
  ran `dbt run -s fct_sales`, and the table was back to 121,253 lines with
  the latest order date 2014-01-28.
- `mf validate-configs`: 0 errors, 0 warnings; `mf query` output above.
- `dbt docs generate`: catalog written.
- `sqlfluff lint models tests`: no violations.
- The CI steps, run in order in a fresh clone of the repository: all passed.
  The workflow itself has not run on GitHub.

Not verified:

- Anything on Snowflake. With dummy values in the environment variables,
  `dbt parse --target snowflake` succeeds (the profile and project parse with
  the Snowflake adapter), but no model has been compiled or run on
  Snowflake, and `scripts/load_snowflake.py` has never been run.

Known limitations:

- dbt-core 1.10 prints a deprecation notice; the project was pinned to 1.10
  on purpose. Moving to a newer dbt means bumping the pins in
  `pyproject.toml`.
- The data is a static extract, so the incremental model and the snapshot
  only show their mechanics; there are no new rows to pick up.

## Data licence

AdventureWorks sample databases are published by Microsoft under the MIT
licence in
[microsoft/sql-server-samples](https://github.com/microsoft/sql-server-samples).
