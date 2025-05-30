-- models/dimensions/dim_officials.sql

{{ config(
    materialized="table"
) }}
-- Or incremental if preferred

-- Unpivot official names and IDs
with officials_unpivoted as (
    select match_referees_id as official_id, match_referees as official_name, 'Referee' as official_role from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where match_referees_id is not null
    union all
    select reserve_umpires_id as official_id, reserve_umpires as official_name, 'Reserve Umpire' as official_role from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where reserve_umpires_id is not null
    union all
    select tv_umpires_id as official_id, tv_umpires as official_name, 'TV Umpire' as official_role from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where tv_umpires_id is not null
    union all
    select umpire_1_id as official_id, umpire_1 as official_name, 'Umpire' as official_role from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where umpire_1_id is not null
    union all
    select umpire_2_id as official_id, umpire_2 as official_name, 'Umpire' as official_role from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where umpire_2_id is not null
    -- Add review_umpire if it has a corresponding ID and needs to be included
    -- select review_umpire_id as official_id, review_umpire as official_name, 'Review Umpire' as official_role from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }} where review_umpire_id is not null

),

-- Select distinct officials
distinct_officials as (
    select distinct
        official_id,
        official_name,
        official_role
    from officials_unpivoted
    where official_id is not null
)

select * from distinct_officials
order by official_name

