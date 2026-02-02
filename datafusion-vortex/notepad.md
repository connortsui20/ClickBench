Create tables from csv:

```sql
-- EA
CREATE TABLE single_58 AS SELECT * FROM read_csv('datafusion-vortex/results-58.csv', header = true, delim = ',', auto_detect = true);
CREATE TABLE single_develop AS SELECT * FROM read_csv('datafusion-vortex/results-develop.csv', header = true, delim = ',', auto_detect = true);
CREATE TABLE partitioned_58 AS SELECT * FROM read_csv('datafusion-vortex-partitioned/results-58.csv', header = true, delim = ',', auto_detect = true);
CREATE TABLE partitioned_develop AS SELECT * FROM read_csv('datafusion-vortex-partitioned/results-develop.csv', header = true, delim = ',', auto_detect = true);
DESCRIBE;
```

Schema should be:

```
D DESCRIBE;
┌──────────┬─────────┬─────────────────────┬────────────────────────────────────────┬──────────────────────────┬───────────┐
│ database │ schema  │        name         │              column_names              │       column_types       │ temporary │
│ varchar  │ varchar │       varchar       │               varchar[]                │        varchar[]         │  boolean  │
├──────────┼─────────┼─────────────────────┼────────────────────────────────────────┼──────────────────────────┼───────────┤
│ memory   │ main    │ partitioned_58      │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
│ memory   │ main    │ partitioned_develop │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
│ memory   │ main    │ single_58           │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
│ memory   │ main    │ single_develop      │ [benchmark_num, run_type, measurement] │ [BIGINT, BIGINT, DOUBLE] │ false     │
└──────────┴─────────┴─────────────────────┴────────────────────────────────────────┴──────────────────────────┴───────────┘
```

Cold run comparison:

```sql
-- (datafusion-vortex) Cold Run Single File Comparison between 0.58.0 and develop
WITH
    single_58_cold AS (
        SELECT benchmark_num, measurement FROM single_58 WHERE run_type = 1
    ),
    single_develop_cold AS (
        SELECT benchmark_num, measurement FROM single_develop WHERE run_type = 1
    )
SELECT
    sd.benchmark_num as "Clickbench Query",
    round(s58.measurement, 4) as "0.58.0 cold runtime",
    round(sd.measurement, 4) as "develop cold runtime",
    round((sd.measurement / s58.measurement - 1) * 100, 4) as "% slowdown (subtract is better)"
FROM single_58_cold as s58, single_develop_cold as sd
WHERE
    s58.benchmark_num = sd.benchmark_num;



-- (datafusion-vortex) Cold Run Partitioned Comparison between 0.58.0 and develop
WITH
    partitioned_58_cold AS (
        SELECT benchmark_num, measurement FROM partitioned_58 WHERE run_type = 1
    ),
    partitioned_develop_cold AS (
        SELECT benchmark_num, measurement FROM partitioned_develop WHERE run_type = 1
    )
SELECT
    sd.benchmark_num as "Clickbench Query",
    round(s58.measurement, 4) as "0.58.0 cold runtime",
    round(sd.measurement, 4) as "develop cold runtime",
    round((sd.measurement / s58.measurement - 1) * 100, 4) as "% slowdown (subtract is better)"
FROM partitioned_58_cold as s58, partitioned_develop_cold as sd
WHERE
    s58.benchmark_num = sd.benchmark_num;
```

Hot run comparison:

```sql
-- (datafusion-vortex) Hot Run Single File Comparison between 0.58.0 and develop
WITH
    single_58_hot AS (
        SELECT benchmark_num, AVG(measurement) as measurement FROM single_58
        WHERE run_type != 1
        GROUP BY benchmark_num
    ),
    single_develop_hot AS (
        SELECT benchmark_num, AVG(measurement) as measurement FROM single_develop
        WHERE run_type != 1
        GROUP BY benchmark_num
    )
SELECT
    sd.benchmark_num as "Clickbench Query",
    round(s58.measurement, 4) as "0.58.0 hot runtime",
    round(sd.measurement, 4) as "develop hot runtime",
    round((sd.measurement / s58.measurement - 1) * 100, 4) as "% slowdown (subtract is better)"
FROM single_58_hot as s58, single_develop_hot as sd
WHERE
    s58.benchmark_num = sd.benchmark_num;



-- (datafusion-vortex) Hot Run Partitioned File Comparison between 0.58.0 and develop
WITH
    partitioned_58_hot AS (
        SELECT benchmark_num, AVG(measurement) as measurement FROM partitioned_58
        WHERE run_type != 1
        GROUP BY benchmark_num
    ),
    partitioned_develop_hot AS (
        SELECT benchmark_num, AVG(measurement) as measurement FROM partitioned_develop
        WHERE run_type != 1
        GROUP BY benchmark_num
    )
SELECT
    sd.benchmark_num as "Clickbench Query",
    round(s58.measurement, 4) as "0.58.0 hot runtime",
    round(sd.measurement, 4) as "develop hot runtime",
    round((sd.measurement / s58.measurement - 1) * 100, 4) as "% slowdown (subtract is better)"
FROM partitioned_58_hot as s58, partitioned_develop_hot as sd
WHERE
    s58.benchmark_num = sd.benchmark_num;
```
