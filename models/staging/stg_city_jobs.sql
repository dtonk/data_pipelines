select
    id,
    title,
    url,
    class_code,
    class_label,
    employment_type,
    department,
    ref_num,
    -- Source stamps carry an offset; parse it, then store UTC-naive so the
    -- published type is stable (see the utc_now() macro).
    released_date::timestamptz at time zone 'UTC' as released_date
from read_json_auto('sources/city_jobs.json')
