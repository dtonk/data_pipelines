{{ config(materialized='table', tags=['ltm_feed']) }}

-- Recently-opened SF food businesses, confirmed actually open. Two signals:
--   1. the business registry lists the location as recently opened & still active
--      ({{ ref('stg_sf_business') }}), and
--   2. it has had a health inspection ({{ ref('stg_sf_inspections') }}) — its first
--      inspection is proof it really opened, not just registered.
-- Inspections are sourced from the registry, so `dba` == `dba_name`; we join on
-- normalized name, with normalized address as a tiebreaker for chains (same name,
-- many locations). The inspection cross-check also restricts to food businesses.
--
-- Output conforms to the Low Tech Maps feed contract: id, name, lat, lng (+ extras).

with biz as (
    select *
    from {{ ref('stg_sf_business') }}
    where lat is not null and lng is not null
),

-- First inspection per business location (existence = proof it opened).
first_inspection as (
    select
        lower(trim(business_name))                    as name_key,
        {{ normalize_address('business_address') }}   as addr_key,
        min(inspection_date)                          as first_inspected
    from {{ ref('stg_sf_inspections') }}
    group by 1, 2
)

select
    b.uniqueid              as id,
    b.dba_name              as name,
    b.full_business_address as address,
    b.lat,
    b.lng,
    b.opened_date,
    f.first_inspected
from biz b
join first_inspection f
  on lower(trim(b.dba_name)) = f.name_key
 and {{ normalize_address('b.full_business_address') }} = f.addr_key
