{{ config(materialized='table', tags=['ltm_feed']) }}

-- SF food businesses *just confirmed open*: opened within the last year AND their
-- FIRST health inspection landed in the recent window (var:first_inspection_window_days).
-- A location is often registered well before it's inspected, so the first inspection
-- is the real "now operating" signal — this feed surfaces those as they happen.
--   biz  = recently-opened, still-active registry locations ({{ ref('stg_sf_business') }})
--   first_inspection = earliest inspection per location ({{ ref('stg_sf_inspections') }})
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
    b.neighborhood,
    b.lat,
    b.lng,
    b.opened_date,
    f.first_inspected,
    CURRENT_TIMESTAMP as data_as_of
from biz b
join first_inspection f
  on lower(trim(b.dba_name)) = f.name_key
 and {{ normalize_address('b.full_business_address') }} = f.addr_key
-- Just confirmed open: first inspection within the recent window.
where f.first_inspected >= current_date - interval '{{ var('first_inspection_window_days', 30) }}' day
