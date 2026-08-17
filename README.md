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

**Recently-opened** SF food businesses, confirmed **actually open**: the registry
says a location opened recently and is still active, and a health inspection proves
it really opened (not just registered). Sources (both DataSF / Socrata):

| dataset | id | role |
|---|---|---|
| Registered Business Locations | `g8m3-pdis` | recently-opened, still-active businesses + coordinates |
| Restaurant Inspections | `tvy3-wexg` | first inspection = proof it actually opened |

Inspections are sourced from the registry, so `dba` matches the registry's
`dba_name` — [`open_restaurants.sql`](models/marts/open_restaurants.sql) joins on
normalized name (plus normalized address, to keep chains matched to the right
location). The inspection cross-check also restricts the registry to food
businesses. Both Socrata pulls are prefiltered server-side via the
[`socrata_json`](macros/socrata.sql) macro (only recent rows + needed columns).
Tune the window with `var:open_lookback_months`; refine
[`normalize_address`](macros/normalize_address.sql) if you hit mismatches.

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

Tagged `reliquery`, not `ltm_feed` — it publishes to Reliquery only, no map feed.

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

Tagged `reliquery`, not `ltm_feed` — no coordinates to map.

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

Feeds publish to a **dedicated public R2 bucket** — kept separate from any bucket
holding app/internal data. R2 public access is per-bucket (all-or-nothing), so a
shared bucket would expose internal objects; a separate bucket is the boundary.

One-time setup in the Cloudflare dashboard:

1. **R2 → Create bucket**, e.g. `ltm-public-feeds`.
2. Bucket **Settings → Public access**: enable the `r2.dev` subdomain (or connect a
   custom domain like `feeds.example.com`). Confirm your app bucket stays private.
3. **Manage R2 API Tokens → Create** with **Object Read & Write**, scoped to *only*
   this bucket — so a leaked key can't touch other data.
4. Copy `.env.example` → `.env` and fill in the token, endpoint,
   `R2_BUCKET_NAME=ltm-public-feeds`, and `R2_PUBLIC_BASE_URL` (the r2.dev or custom
   domain). Add the same as repo Actions secrets for CI (see Scheduling).

Without `.env`, the exporter just writes local files under `out/`.

## Publishing (Reliquery)

Models tagged `reliquery` also publish to [reliquery.net](https://reliquery.net),
a queryable open-data portal, via `scripts/publish_reliquery.py`:

```bash
dbt run --profiles-dir .
python scripts/publish_reliquery.py   # needs DSP_TOKEN in .env
```

The first run creates the dataset and records its id in
`reliquery_datasets.json` (committed to the repo); later runs `PUT` to that
id to refresh contents in place. To publish another model, tag it
`reliquery` — discovery is tag-driven, same as `ltm_feed`. Pass model names to
publish only a subset, e.g. `python scripts/publish_reliquery.py city_jobs`
(used by the narrower `city_jobs` workflow, see Scheduling).

## Scheduling

[`.github/workflows/build.yml`](.github/workflows/build.yml) runs `dbt run` +
export weekly (Mondays 11:30 UTC) and on manual dispatch. Add the `R2_*` repo
secrets to enable publishing. Low Tech Maps then refreshes from the URL on its own
cadence.

[`.github/workflows/build-city-jobs.yml`](.github/workflows/build-city-jobs.yml)
runs `city_jobs` on its own, more frequent schedule (8 AM / 2 PM Pacific, matching
`city_job_alerts`) since job postings are time-sensitive. Add the `DSP_TOKEN` repo
secret to enable publishing.
