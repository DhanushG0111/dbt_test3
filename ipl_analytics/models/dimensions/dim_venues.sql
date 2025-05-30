-- models/dimensions/dim_venues.sql

{{ config(
    materialized="table" 
) }}
-- Or incremental if preferred

with source_data as (
    select distinct
        venue,
        city
    from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }}
    where venue is not null and city is not null
),

generate_key as (
    select
        -- Generate surrogate key using MD5 hash of identifying columns
        {{ dbt_utils.generate_surrogate_key([
            "venue",
            "city"
        ]) }} as venue_id,
        venue as venue_name,
        city
    from source_data
)

select * from generate_key
order by city, venue_name

