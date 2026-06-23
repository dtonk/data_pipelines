-- Source: DataSF "Map of Schools in San Francisco" (7e7j-59qk), Socrata JSON.
-- Active public schools with coordinates. name_key is produced by the shared
-- normalize_school_name macro for joining to the SFUSD waitlist data.
with raw as (
    select *
    from {{ socrata_json(
        '7e7j-59qk',
        select='school, status, latitude, longitude, street_address, analysis_neighborhood, entity_type, low_grade, high_grade, phone',
        where="public_yesno = true AND status IN('Active', 'Pending')"
    ) }}
)

select
    school,
    try_cast(latitude as double)  as lat,
    try_cast(longitude as double) as lng,
    street_address                as address,
    analysis_neighborhood         as neighborhood,
    entity_type,
    low_grade,
    high_grade,
    phone,
    {{ normalize_school_name('school') }} as name_key
from raw
where latitude is not null and longitude is not null
