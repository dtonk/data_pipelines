-- Source: DataSF "Registered Business Locations" (g8m3-pdis), Socrata JSON.
-- The "recently opened" side: businesses whose location opened within the lookback
-- window (var:business_open_lookback_months) and is still active (no end date).
-- Prefiltered server-side to those rows and only the columns we use. Future-dated
-- junk start dates are excluded.
{%- set lookback = var('business_open_lookback_months', 12) -%}
{%- set today = modules.datetime.date.today() -%}
{%- set cutoff = (today - modules.datetime.timedelta(days=lookback * 31)).isoformat() %}
with raw as (
    select *
    from {{ socrata_json(
        'g8m3-pdis',
        select='uniqueid, dba_name, full_business_address, city, business_zip, location_start_date, location_end_date, location',
        where="location_end_date IS NULL"
              ~ " AND location_start_date >= '" ~ cutoff ~ "'"
              ~ " AND location_start_date <= '" ~ today.isoformat() ~ "'"
    ) }}
)

select
    uniqueid,
    dba_name,
    full_business_address,
    city,
    business_zip,
    try_cast(location_start_date as date)        as opened_date,
    -- Socrata point: {"type":"Point","coordinates":[lng,lat]} → DuckDB STRUCT.
    try_cast(location.coordinates[1] as double)  as lng,
    try_cast(location.coordinates[2] as double)  as lat
from raw
