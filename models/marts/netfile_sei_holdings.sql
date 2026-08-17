{{ config(materialized='table', tags=['reliquery'], meta={'reliquery_primary_key': 'transaction_id'}) }}

-- SF employee/official financial-interest disclosures (Form 700), one row per
-- schedule item. Schedule shape varies a lot (a stock holding and a gift
-- share almost no fields), so this pulls out the handful of fields worth
-- normalizing across schedules and keeps the rest in `content` for anyone
-- who needs schedule-specific detail (e.g. `content->>'$.Loan'` on Schedule C).
--
-- FPPC fair-market-value/income brackets (Schedule A-1/A-2's FairMarketValue,
-- GrossIncomeReceived, etc.) come back from NetFile as small integer codes
-- with no accompanying label — rather than guess at the FPPC bracket text,
-- those are passed through as `*_code` columns.
select
    transaction_id,
    filing_id,
    filer_name,
    department,
    position,
    schedule_code,
    case schedule_code
        when 'ScheduleA1' then 'Investments (Stocks, etc.)'
        when 'ScheduleA2' then 'Investments in Business Entities / Trusts'
        when 'ScheduleB'  then 'Real Property'
        when 'ScheduleC'  then 'Income & Loans'
        when 'ScheduleD'  then 'Gifts'
        when 'ScheduleE'  then 'Travel Payments'
        else schedule_code
    end as schedule_name,

    -- Who/what the item is about — the field holding this differs by schedule.
    coalesce(
        json_extract_string(content, '$.NameOfBusinessEntity'), -- A1
        json_extract_string(content, '$.EntityName'),           -- A2
        json_extract_string(content, '$.NameOfIncomeSource'),   -- C
        json_extract_string(content, '$.NameOfSource')          -- D, E
    ) as entity_or_source,

    coalesce(
        json_extract_string(content, '$.DescriptionAsString'),      -- A1
        json_extract_string(content, '$.Description'),              -- A2
        json_extract_string(content, '$.NatureOfInterestAsString'), -- B
        json_extract_string(content, '$.BusinessActivity'),         -- C, D
        json_extract_string(content, '$.BusinessActivityAsString')  -- E
    ) as description,

    coalesce(
        json_extract_string(content, '$.City'),         -- B
        json_extract_string(content, '$.Address.City')  -- A2, C, D, E
    ) as location_city,

    try_cast(json_extract_string(content, '$.DateAcquired') as timestamp) as date_acquired,
    try_cast(json_extract_string(content, '$.DateDisposed') as timestamp) as date_disposed,

    -- A1/A2 fair-market-value bracket, raw FPPC code (see note above).
    coalesce(
        try_cast(json_extract_string(content, '$.FairMarketValue') as integer),
        try_cast(json_extract_string(content, '$.FairMarketValueScheduleA2') as integer)
    ) as fair_market_value_code,
    json_extract_string(content, '$.FairMarketValueAsString') as fair_market_value_range, -- B only

    -- Real dollar amounts: E reports one payment; D can bundle multiple gifts
    -- from the same source, so those are summed.
    coalesce(
        try_cast(json_extract_string(content, '$.Amount') as double), -- E
        list_sum(list_transform(
            from_json(json_extract(content, '$.Gifts'), '["JSON"]'),
            x -> try_cast(json_extract_string(x, '$.Amount') as double)
        ))                                                            -- D
    ) as amount_usd,

    is_archived,
    is_superseded,
    filing_date,
    period_start,
    period_end,
    year,
    content,
    {{ utc_now() }} as data_as_of
from {{ ref('stg_netfile_sei_transactions') }}
