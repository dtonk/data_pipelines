-- Source: DataSF "Restaurant Scores – LIVES Standard" (pyih-qa8i), Socrata JSON.
-- One row per (business, inspection, violation); we dedup to the latest
-- inspection per business downstream.
with raw as (
    select *
    from read_json_auto(
        'https://data.sfgov.org/resource/pyih-qa8i.json?$limit={{ var("max_rows") }}'
    )
)

select
    business_id,
    business_name,
    business_address,
    try_cast(business_latitude as double)   as lat,
    try_cast(business_longitude as double)  as lng,
    try_cast(inspection_date as date)       as inspection_date,
    try_cast(inspection_score as integer)   as inspection_score,
    inspection_type
from raw
where business_name is not null
