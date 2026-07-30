{{ config(materialized='table', tags=['reliquery'], meta={'reliquery_primary_key': 'id'}) }}

select
    id,
    title,
    url,
    class_code,
    class_label,
    employment_type,
    department,
    ref_num,
    released_date,
    current_timestamp as data_as_of
from {{ ref('stg_city_jobs') }}
where employment_type in ('{{ var('city_job_employment_types') | join("', '") }}')
{% if var('city_job_classes') %}
  and class_code in ('{{ var('city_job_classes') | join("', '") }}')
{% endif %}
