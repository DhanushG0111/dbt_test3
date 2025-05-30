-- models/dimensions/dim_teams.sql

{{ config(
    materialized="table"
) }}
-- Or incremental if preferred

with team_names as (
    -- Consolidate all unique team names from various columns
    select team_1 as team_name, team_type from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where team_1 is not null
    union
    select team_2 as team_name, team_type from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where team_2 is not null
    union
    select toss_winner as team_name, team_type from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where toss_winner is not null
    union
    select match_winner as team_name, team_type from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where match_winner is not null
),

distinct_teams as (
    select distinct 
        team_name,
        team_type -- Assuming team_type is consistent for a given team_name
    from team_names
),

generate_key as (
    select
        -- Generate surrogate key using MD5 hash of identifying columns
        {{ dbt_utils.generate_surrogate_key([
            "team_name",
            "team_type"
        ]) }} as team_id,
        team_name,
        team_type
    from distinct_teams
)

select * from generate_key
order by team_name

