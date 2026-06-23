{# Normalize a school name to a stable join key. Strips common type suffixes,
   modifier words, punctuation, and collapses whitespace. Applied identically to
   both the sfgov school list and the SFUSD waitlist so names like
   "Alamo Elementary" and "Alamo ES" produce the same key ("alamo"). #}
{% macro normalize_school_name(column) %}
    lower(trim(regexp_replace(
        regexp_replace(
            regexp_replace(
                regexp_replace({{ column }}, '[\.\/,]', ' ', 'g'),
                '\s*(Elementary|Middle|High|School for Equity|School|ES|MS|HS|K-8|K-5|EES|Children Centers?|SF Sch of the Arts A Public School)\s*$', '', 'gi'
            ),
            '\s*(Alternative|Academic|Traditional|FEC|SOTA)\s*$', '', 'gi'
        ),
        '\s+', ' ', 'g'
    )))
{% endmacro %}
