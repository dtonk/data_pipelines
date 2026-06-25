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
    p.prior_waitlist,
    p.prior_offers_made,
    w.current_waitlist - coalesce(p.prior_waitlist, w.current_waitlist) as waitlist_change,
    w.offers_made - coalesce(p.prior_offers_made, w.offers_made) as offers_change,
    p.prior_data_as_of,
    current_timestamp as data_as_of
from {{ ref('stg_sfusd_waitlist') }} w
inner join {{ ref('stg_sf_schools') }} s
    on w.name_key = s.name_key
left join {{ ref('stg_prior_waitlist') }} p
    on w.school_name = p.school
    and w.grade = p.grade
    and w.program_code = p.program_code
