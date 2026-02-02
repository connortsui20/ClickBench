Script to convert the existing results:

```py
import json
import csv
import sys

def convert(input_path, output_path):
    with open(input_path) as f:
        data = json.load(f)

    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["benchmark_num", "run_type", "measurement"])
        for i, runs in enumerate(data["result"]):
            for run_type, measurement in enumerate(runs, start=1):
                assert run_type > 0
                writer.writerow([i, run_type, measurement])

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.json> <output.csv>")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
```

Create tables from csv:

```sql
CREATE TABLE single_34           AS FROM read_csv('datafusion-vortex/results-34.csv');
CREATE TABLE single_58           AS FROM read_csv('datafusion-vortex/results-58.csv');
CREATE TABLE single_develop      AS FROM read_csv('datafusion-vortex/results-develop.csv');
CREATE TABLE partitioned_44      AS FROM read_csv('datafusion-vortex-partitioned/results-44.csv');
CREATE TABLE partitioned_58      AS FROM read_csv('datafusion-vortex-partitioned/results-58.csv');
CREATE TABLE partitioned_develop AS FROM read_csv('datafusion-vortex-partitioned/results-develop.csv');
DESCRIBE;
```

Schema should be:

```
D DESCRIBE;
┌──────────┬─────────┬─────────────────────┬────────────────────────────────────────┬──────────────────────────┬───────────┐
│ database │ schema  │        name         │              column_names              │       column_types       │ temporary │
│ varchar  │ varchar │       varchar       │               varchar[]                │        varchar[]         │  boolean  │
├──────────┼─────────┼─────────────────────┼────────────────────────────────────────┼──────────────────────────┼───────────┤
│ memory   │ main    │ partitioned_44      │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
│ memory   │ main    │ partitioned_58      │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
│ memory   │ main    │ partitioned_develop │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
│ memory   │ main    │ single_34           │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
│ memory   │ main    │ single_58           │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
│ memory   │ main    │ single_develop      │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
└──────────┴─────────┴─────────────────────┴────────────────────────────────────────┴──────────────────────────┴───────────┘
```

Define comparison macros:

```sql
-- query_table() lets us pass table names as strings to macros.

CREATE OR REPLACE MACRO cold_compare(base, dev) AS TABLE
    WITH
        base_cold AS (
            SELECT benchmark_num, measurement FROM query_table(base) WHERE run_type = 1
        ),
        dev_cold AS (
            SELECT benchmark_num, measurement FROM query_table(dev) WHERE run_type = 1
        )
    SELECT
        d.benchmark_num AS "Clickbench Query",
        round(b.measurement, 4) AS "base cold runtime",
        round(d.measurement, 4) AS "develop cold runtime",
        round((d.measurement / b.measurement - 1) * 100, 4) AS "% slowdown (negative is better)"
    FROM base_cold b JOIN dev_cold d USING (benchmark_num);

CREATE OR REPLACE MACRO hot_compare(base, dev) AS TABLE
    WITH
        base_hot AS (
            SELECT benchmark_num, AVG(measurement) AS measurement
            FROM query_table(base) WHERE run_type != 1
            GROUP BY benchmark_num
        ),
        dev_hot AS (
            SELECT benchmark_num, AVG(measurement) AS measurement
            FROM query_table(dev) WHERE run_type != 1
            GROUP BY benchmark_num
        )
    SELECT
        d.benchmark_num AS "Clickbench Query",
        round(b.measurement, 4) AS "base hot runtime",
        round(d.measurement, 4) AS "develop hot runtime",
        round((d.measurement / b.measurement - 1) * 100, 4) AS "% slowdown (negative is better)"
    FROM base_hot b JOIN dev_hot d USING (benchmark_num);
```

Run comparisons:

```sql
-- Cold
FROM cold_compare('single_34', 'single_58');
FROM cold_compare('single_58', 'single_develop');
FROM cold_compare('partitioned_58', 'partitioned_develop');

-- Hot
FROM hot_compare('single_34', 'single_58');
FROM hot_compare('single_58', 'single_develop');
FROM hot_compare('partitioned_58', 'partitioned_develop');
```
