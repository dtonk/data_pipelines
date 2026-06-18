{# Build a Socrata read_json_auto() call with server-side prefiltering, so we pull
   only the columns/rows we need instead of the whole dataset.
     dataset  Socrata resource id, e.g. 'g8m3-pdis'
     select   comma-separated column list ($select)  — fewer columns
     where    SoQL filter ($where)                    — fewer rows
   $limit comes from var('max_rows'). Spaces are URL-encoded; keep SoQL simple. #}
{% macro socrata_json(dataset, select=none, where=none) %}
    {%- set params = [] -%}
    {%- if select -%}{%- do params.append('$select=' ~ (select | replace(' ', ''))) -%}{%- endif -%}
    {%- if where -%}
        {#- URL-encode the SoQL: %27 for quotes (else they'd close the SQL string
            literal wrapping this URL), %20/%3E/%3C for space and comparisons. -#}
        {%- set enc = where | replace("'", '%27') | replace(' ', '%20') | replace('>', '%3E') | replace('<', '%3C') -%}
        {%- do params.append('$where=' ~ enc) -%}
    {%- endif -%}
    {%- do params.append('$limit=' ~ var('max_rows')) -%}
    read_json_auto('https://data.sfgov.org/resource/{{ dataset }}.json?{{ params | join('&') }}')
{% endmacro %}
