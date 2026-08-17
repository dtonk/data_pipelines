-- Source: SF Ethics Commission Statement of Economic Interests (Form 700)
-- filings, via NetFile's public portal (see scripts/fetch_netfile_sei.py).
-- One row per disclosed schedule item. `content` stays a raw JSON string
-- since its shape differs by schedule (a stock holding and a gift share
-- almost no fields) — the mart extracts what's worth normalizing per type.
--
-- distinct: the ~130k-row fetch pages over a couple minutes, and rows can
-- shift a page during that window (results are sorted by filing date, which
-- keeps changing as new filings land), producing a handful of exact-duplicate
-- rows across adjacent pages.
select distinct
    id                                                as transaction_id,
    filingId                                          as filing_id,
    filerName                                         as filer_name,
    departmentName                                    as department,
    positionName                                      as position,
    templateName                                      as schedule_code,
    year,
    filingDate::timestamptz at time zone 'UTC'         as filing_date,
    periodStart::timestamptz at time zone 'UTC'        as period_start,
    periodEnd::timestamptz at time zone 'UTC'          as period_end,
    isArchived                                         as is_archived,
    isSuperceded                                       as is_superseded,
    content
from read_json_auto('sources/netfile_sei_transactions.json')
