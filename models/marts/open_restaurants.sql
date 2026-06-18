{{ config(materialized='table', tags=['ltm_feed']) }}

-- SF registered food businesses confirmed still operating by a recent health
-- inspection. The inspections feed is sourced from the business registry, so the
-- names align — we join on normalized business name. Address is added to the join
-- only to keep chains (same name, many locations) matched to the right site; drop
-- it if it costs you matches.
--
-- Output conforms to the Low Tech Maps feed contract: id, name, lat, lng (+ extras).

with biz as (
    select *
    from {{ ref('stg_sf_business') }}
    where location_end_date is null          -- city still lists it as active
      and lat is not null and lng is not null
),

recent_inspections as (
    select *
    from {{ ref('stg_sf_inspections') }}
    where inspection_date >= current_date - interval 18 month
),

matched as (
    select
        b.uniqueid                    as id,
        b.dba_name                    as name,
        b.full_business_address       as address,
        b.lat,
        b.lng,
        i.inspection_date             as last_inspected,
        i.inspection_score,
        row_number() over (
            partition by b.uniqueid order by i.inspection_date desc
        ) as rn
    from biz b
    join recent_inspections i
      on lower(trim(b.dba_name)) = lower(trim(i.business_name))
     and {{ normalize_address('b.full_business_address') }}
           = {{ normalize_address('i.business_address') }}
)

-- Keep one row per business (its most recent matching inspection).
select id, name, address, lat, lng, last_inspected, inspection_score
from matched
where rn = 1
