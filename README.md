# data_pipelines

Lightweight, dbt-style data prep for [Low Tech Maps](https://overlaymaps.net).
Pull open datasets, clean and join them with SQL, and publish each result as a
JSON feed that a Low Tech Maps map can import and auto-refresh.

- **Transform** with [dbt-duckdb](https://github.com/duckdb/dbt-duckdb) — same dbt
  workflow you know (`source`/`ref`/tests), but DuckDB is embedded (no database to
  run) and reads remote CSV/JSON directly.
- **Publish** every model tagged `ltm_feed` as a JSON array to Cloudflare R2 (or
  local files). Low Tech Maps pulls the public URL on its own schedule.

## First pipeline: `open_restaurants`

SF registered food businesses, cross-checked against health inspections so the
map only shows places that are **actually operating** (inspected in the last 18
months). Sources (both DataSF / Socrata):

| dataset | id | role |
|---|---|---|
| Registered Business Locations | `g8m3-pdis` | the businesses + coordinates |
| Restaurant Scores – LIVES | `pyih-qa8i` | proof of recent operation |

The inspections feed is sourced from the business registry, so the business names
align — [`open_restaurants.sql`](models/marts/open_restaurants.sql) joins on
normalized name (plus normalized address, to keep chains matched to the right
location). Refine [`normalize_address`](macros/normalize_address.sql) if you hit
mismatches.

## The Low Tech Maps feed contract

Every `ltm_feed` model should emit flat columns Low Tech Maps can map:

- `id` — stable, unique → the feed's upsert key
- `name` → POI title
- `lat` + `lng` (or a clean `address` to geocode)
- optional: `category`, `description`, `link_url`, and dates as `YYYY-MM-DD`

## Run it locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

dbt run  --profiles-dir .        # builds ./warehouse.duckdb
dbt test --profiles-dir .        # data-quality checks
python scripts/export_feeds.py   # writes ./out/<model>.json (and R2 if configured)
```

Point a Low Tech Maps feed at the published URL (e.g. `https://<public-r2>/feeds/open_restaurants.json`),
map the columns once, pick a refresh interval, done.

## Add another pipeline

The framework is the convention — no plumbing to touch:

1. Add staging model(s) in `models/staging/` that `read_json_auto(...)` /
   `read_csv_auto(...)` the new source.
2. Add a mart in `models/marts/` that outputs the feed contract above and is
   tagged `{{ config(tags=['ltm_feed']) }}`.
3. `dbt run && python scripts/export_feeds.py` — the exporter discovers it by tag
   and publishes `out/<your_model>.json`.

## Publishing (R2)

Copy `.env.example` → `.env` and fill in R2 creds for a **public** bucket (you can
reuse the account you use for map backups; use a separate public bucket). Without
`.env`, the exporter just writes local files under `out/`.

## Scheduling

[`.github/workflows/build.yml`](.github/workflows/build.yml) runs `dbt run` +
export weekly (Mondays 11:30 UTC) and on manual dispatch. Add the `R2_*` repo
secrets to enable publishing. Low Tech Maps then refreshes from the URL on its own
cadence.
