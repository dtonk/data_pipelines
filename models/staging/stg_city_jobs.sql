select
    id,
    title,
    url,
    class_code,
    class_label,
    employment_type,
    department,
    ref_num,
    released_date::timestamptz as released_date
from read_json_auto('sources/city_jobs.json')
