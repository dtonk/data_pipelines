-- Reads the currently-published R2 feed to capture last week's snapshot
-- before the pipeline overwrites it with fresh data.
select
    school,
    grade,
    program_code,
    current_waitlist as prior_waitlist,
    offers_made     as prior_offers_made,
    data_as_of      as prior_data_as_of
from read_json_auto(
    'https://pub-4b600ed6f592436bbfbcffa049c4dc4b.r2.dev/feeds/school_waitlists.json'
)
