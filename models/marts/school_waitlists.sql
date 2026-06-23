{{ config(materialized='table', tags=['ltm_feed']) }}

select
    w.school_name  as school,
    w.grade,
    w.program_name as program,
    w.program_code,
    w.initial_waitlist,
    w.current_waitlist,
    w.offers_made,
    w.offers_last_year,
    s.lat,
    s.lng,
    s.address,
    s.neighborhood,
    current_timestamp as data_as_of
from {{ ref('stg_sfusd_waitlist') }} w
inner join {{ ref('stg_sf_schools') }} s
    on w.name_key = s.name_key
