{# Current wall-clock UTC as a *naive* TIMESTAMP, for `data_as_of`-style stamps.

   DuckDB's current_timestamp is TIMESTAMP WITH TIME ZONE, which COPY ... TO CSV
   renders with the session's offset ("2026-08-07 12:18:53-07" locally, "+00" on a
   CI runner). Reliquery infers column types from that CSV, so a tz-aware stamp
   both reads as a different type than the TIMESTAMP already stored — a breaking
   schema change, rejected with 409 — and carries an offset that varies with
   whoever ran the pipeline. Normalizing to UTC pins the type and the value. #}
{% macro utc_now() %}
    (current_timestamp at time zone 'UTC')
{% endmacro %}
