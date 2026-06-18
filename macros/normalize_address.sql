{# Best-effort street-address normalizer for joining across datasets that don't
   share a key. Lowercases, drops periods, collapses common abbreviations, and
   strips trailing suite/unit/floor tokens. Iterate on this as you hit mismatches. #}
{% macro normalize_address(col) %}
    trim(
        regexp_replace(
            regexp_replace(
                regexp_replace(lower({{ col }}), '\.', '', 'g'),
                '\b(street|str)\b', 'st', 'g'
            ),
            '\s+(ste|suite|unit|fl|floor|rm|room|#)\s*\w+\s*$', '', 'g'
        )
    )
{% endmacro %}
