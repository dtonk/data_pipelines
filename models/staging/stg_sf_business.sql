-- Source: DataSF "Registered Business Locations" (g8m3-pdis), Socrata JSON.
-- The "recently opened" side: businesses whose location opened within the lookback
-- window (var:business_open_lookback_months) and is still active (no end date).
-- Prefiltered server-side to those rows and only the columns we use. Future-dated
-- junk start dates are excluded.
-- Food businesses are identified by a RESTAURANT license or a NAICS code under 722
-- (Food Services and Drinking Places). DataSF dropped the derived
-- `naic_code_description` column in Aug 2026, leaving only the raw self-reported
-- code — hence the prefix match, which also absorbs the varying code lengths
-- ('722', '7220', '722511') that self-reporting produces.
{%- set lookback = var('business_open_lookback_months', 12) -%}
{%- set today = modules.datetime.date.today() -%}
{%- set cutoff = (today - modules.datetime.timedelta(days=lookback * 31)).isoformat() %}
with raw as (
    select *
    from {{ socrata_json(
        'g8m3-pdis',
        select='uniqueid, dba_name, full_business_address, city, business_zip, dba_start_date, location_end_date, location, self_reported_naics_code, lic_code_description, neighborhoods_analysis_boundaries',
        where="location_end_date IS NULL"
              ~ " AND dba_start_date >= '" ~ cutoff ~ "'"
              ~ " AND dba_start_date <= '" ~ today.isoformat() ~ "'"
              ~ " AND (lic_code_description like '%RESTAURANT%' OR starts_with(self_reported_naics_code, '722'))"
    ) }}
)

select
    uniqueid,
    dba_name,
    full_business_address,
    city,
    business_zip,
    neighborhoods_analysis_boundaries        as neighborhood,
    try_cast(dba_start_date as date)        as opened_date,
    -- Socrata point: {"type":"Point","coordinates":[lng,lat]} → DuckDB STRUCT.
    try_cast(location.coordinates[1] as double)  as lng,
    try_cast(location.coordinates[2] as double)  as lat
from raw
