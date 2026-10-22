# data_pipelines

Lightweight, dbt-style data prep for SF open data. Pull datasets, clean and join
them with SQL, and publish each result to [Reliquery](https://reliquery.net).

- **Transform** with [dbt-duckdb](https://github.com/duckdb/dbt-duckdb) — same dbt
  workflow you know (`source`/`ref`/tests), but DuckDB is embedded (no database to
  run).
- **Publish** every model tagged `reliquery` via `scripts/publish_reliquery.py`.

## `city_jobs`

SF city job postings (Permanent/Temporary Exempt) from the SmartRecruiters API
behind [careers.sf.gov](https://careers.sf.gov), filtered to the job classes in
`var:city_job_classes` (`dbt_project.yml`) — mirrors the filter used by the
separate [`city_job_alerts`](https://github.com/dtonk/projects/tree/main/city_job_alerts)
repo, which independently emails alerts on new postings; this pipeline only
publishes the current snapshot, it doesn't send email.

SmartRecruiters caps postings at 100/page, so unlike the Socrata sources this
can't be a single `read_json_auto()` call — `scripts/fetch_city_jobs.py` paginates
and flattens to `sources/city_jobs.json` (gitignored) before `dbt run`:

```bash
python scripts/fetch_city_jobs.py
dbt run --profiles-dir .
```

## `netfile_sei_holdings`

SF employees'/officials' Form 700 (Statement of Economic Interests) disclosures —
stock holdings, real property, income sources, gifts, travel payments — from the
[SF Ethics Commission's public NetFile portal](https://netfile.com/public/SFO/sei).
One row per disclosed item; schedule-specific detail that isn't worth normalizing
across schedules stays in the `content` JSON column.

NetFile has no public API docs — `scripts/fetch_netfile_sei.py` calls an endpoint
reverse-engineered from the portal's JS bundle (`api/searchtransactions`), paginates
the ~130k rows, and flattens to `sources/netfile_sei_transactions.json` before
`dbt run`:

```bash
python scripts/fetch_netfile_sei.py
dbt run --profiles-dir .
```

## Run it locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

dbt run  --profiles-dir .        # builds ./warehouse.duckdb
dbt test --profiles-dir .        # data-quality checks
```

## Publishing (Reliquery)

Models tagged `reliquery` publish to [reliquery.net](https://reliquery.net),
a queryable open-data portal, via `scripts/publish_reliquery.py`:

```bash
dbt run --profiles-dir .
python scripts/publish_reliquery.py   # needs DSP_TOKEN in .env
```

The first run creates the dataset and records its id in
`reliquery_datasets.json` (committed to the repo); later runs `PUT` to that
id to refresh contents in place. To publish another model, tag it
`reliquery` — discovery is tag-driven. Pass model names to
publish only a subset, e.g. `python scripts/publish_reliquery.py city_jobs`
(used by the narrower `city_jobs` workflow, see Scheduling).

## Scheduling

[`.github/workflows/build-city-jobs.yml`](.github/workflows/build-city-jobs.yml)
runs `city_jobs` on a twice-daily schedule (8 AM / 2 PM Pacific, matching
`city_job_alerts`) since job postings are time-sensitive. Add the `DSP_TOKEN` repo
secret to enable publishing.

[`.github/workflows/build-netfile-sei.yml`](.github/workflows/build-netfile-sei.yml)
runs `netfile_sei_holdings` on manual dispatch only — SEI filings don't change
often enough to warrant a schedule.
