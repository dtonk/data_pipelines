-- Source: SFUSD Waitlist Google Sheet (public). Rows 1-2 are metadata, row 3 is
-- the header (with multi-line translations), data starts at row 4. We skip the
-- header and define columns explicitly to keep names clean.
-- Sheet URL: https://docs.google.com/spreadsheets/d/1hatg8laSrgwwH8Zf1z4RPCNF0ICIX7rEXv3aq5f3FDo
{%- set sheet_id = '1hatg8laSrgwwH8Zf1z4RPCNF0ICIX7rEXv3aq5f3FDo' -%}
{%- set gid      = '1104076014' %}
with raw as (
    select * from read_csv(
        'https://docs.google.com/spreadsheets/d/{{ sheet_id }}/gviz/tq?tqx=out:csv&gid={{ gid }}&range=A4:J',
        header = false,
        columns = {
            'concat_key':      'VARCHAR',
            'school_code':     'VARCHAR',
            'school_name':     'VARCHAR',
            'grade':           'VARCHAR',
            'program_code':    'VARCHAR',
            'program_name':    'VARCHAR',
            'initial_waitlist':'VARCHAR',
            'current_waitlist':'VARCHAR',
            'offers_made':     'VARCHAR',
            'offers_last_year':'VARCHAR'
        }
    )
    where school_name is not null and trim(school_name) != ''
),

mapped as (
    select
        *,
        case school_name
            when 'Asawa (Ruth) SOTA HS'                             then 'Asawa (Ruth) SF Sch of the Arts, A Public School'
            when 'Brown Jr. (Willie) MS'                            then 'Brown Jr. (Willie L) Middle'
            when 'Buena Vista Horace Mann K-8'                      then 'Buena Vista/ Horace Mann K-8'
            when 'Burton (Phillip and Sala) HS'                     then 'Burton (Phillip and Sala) Academic High'
            when 'Carmichael (Bessie) K-8'                          then 'Carmichael (Bessie)/FEC'
            when 'Clarendon ES'                                     then 'Clarendon Alternative Elementary'
            when 'Cobb (Dr William L) ES'                           then 'Cobb (William L.) Elementary'
            when 'Drew (Dr Charles) College Preparatory Academy ES' then 'Drew (Charles) College Preparatory Academy'
            when 'Flynn (Leonard R) ES'                             then 'Flynn (Leonard R.) Elementary'
            when 'Jordan (June) HS'                                 then 'Jordan (June) School for Equity'
            when 'King Jr (Dr Martin L) MS'                         then 'King Jr. (Martin Luther) Academic Middle'
            when 'Lakeshore ES'                                     then 'Lakeshore Alternative Elementary'
            when 'Lau (Gordon J) ES'                                then 'Lau (Gordon J.) Elementary'
            when 'Lawton K-8'                                       then 'Lawton Alternative'
            when 'Milk (Harvey) Civil Right ES'                     then 'Milk (Harvey) Civil Rights Elementary'
            when 'Moscone (George R) ES'                            then 'Moscone (George R.) Elementary'
            when 'Noriega EES'                                      then 'Noriega Children Center'
            when 'SF Community K-8'                                 then 'San Francisco Community Alternative'
            when 'SF International HS'                              then 'S.F. International High'
            when 'SF Public Montessori ES'                          then 'San Francisco Public Montessori'
            when 'San Miguel EES'                                   then 'San Miguel Children Center'
            when 'Spring Valley Science ES'                         then 'Spring Valley Elementary'
            when 'Stockton (Commodore) EES'                         then 'Stockton (Commodore) Children Center'
            when 'Taylor (Edward R) ES'                             then 'Taylor (Edward R.) Elementary'
            when 'Tule Elk Park EES'                                then 'Tule Elk Park Children Center'
            when 'Wallenberg (Raoul) HS'                            then 'Wallenberg (Raoul) Traditional High'
            when 'Wo (Yick) ES'                                     then 'Yick Wo Elementary'
            else school_name
        end as sfgov_name
    from raw
)

select
    school_code,
    school_name,
    coalesce(
        nullif(trim(grade), ''),
        substr(concat_key, length(school_name) + 1,
               length(concat_key) - length(school_name) - length(program_code))
    ) as grade,
    program_code,
    program_name,
    try_cast(initial_waitlist as integer) as initial_waitlist,
    try_cast(current_waitlist as integer) as current_waitlist,
    try_cast(offers_made      as integer) as offers_made,
    try_cast(offers_last_year as integer) as offers_last_year,
    {{ normalize_school_name('sfgov_name') }} as name_key
from mapped
