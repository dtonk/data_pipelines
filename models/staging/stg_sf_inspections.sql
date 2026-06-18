-- Source: DataSF "Restaurant Inspections" (tvy3-wexg), Socrata JSON. Actively
-- updated; sourced from the business registry, so `dba` matches the registry's
-- `dba_name`. The "actually open" side: presence of an inspection proves the
-- business really opened. Prefiltered server-side to the lookback window (a
-- recently-opened business's first inspection falls inside it) and the columns we
-- use. Future-dated junk inspection dates are excluded.
{%- set lookback = var('open_lookback_months', 12) -%}
{%- set today = modules.datetime.date.today() -%}
{%- set cutoff = (today - modules.datetime.timedelta(days=lookback * 31)).isoformat() %}
with raw as (
    select *
    from {{ socrata_json(
        'tvy3-wexg',
        select='dba, street_address_clean, inspection_date',
        where="inspection_date >= '" ~ cutoff ~ "'"
              ~ " AND inspection_date <= '" ~ today.isoformat() ~ "'"
    ) }}
)

select
    dba                                  as business_name,
    street_address_clean                 as business_address,
    try_cast(inspection_date as date)    as inspection_date
from raw
where dba is not null
