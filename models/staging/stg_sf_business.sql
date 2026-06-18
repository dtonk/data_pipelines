-- Source: DataSF "Registered Business Locations" (g8m3-pdis), Socrata JSON.
-- read_json_auto pulls the live endpoint over httpfs. Raise var:max_rows (and add
-- a Socrata app token) for a full load.
with raw as (
    select *
    from read_json_auto(
        'https://data.sfgov.org/resource/g8m3-pdis.json?$limit={{ var("max_rows") }}'
    )
)

select
    uniqueid,
    dba_name,
    full_business_address,
    city,
    business_zip,
    try_cast(location_end_date as date)          as location_end_date,
    -- Socrata point: {"type":"Point","coordinates":[lng,lat]} → DuckDB STRUCT.
    -- Lists are 1-indexed: [1]=lng, [2]=lat. If your DuckDB infers `location` as
    -- text instead, swap to json_extract(location, '$.coordinates[0]') etc.
    try_cast(location.coordinates[1] as double)  as lng,
    try_cast(location.coordinates[2] as double)  as lat
from raw
