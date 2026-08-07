-- Reads the currently-published R2 feed to capture last week's snapshot
-- before the pipeline overwrites it with fresh data.
select
    school,
    grade,
    program_code,
    current_waitlist as prior_waitlist,
    offers_made     as prior_offers_made,
    -- Arrives as text from the feed; may or may not carry an offset depending on
    -- when it was published. try_cast reads either, UTC-naive keeps the type stable.
    try_cast(data_as_of as timestamptz) at time zone 'UTC' as prior_data_as_of
from read_json_auto(
    'https://pub-4b600ed6f592436bbfbcffa049c4dc4b.r2.dev/feeds/school_waitlists.json'
)
