-- models/dimensions/dim_matches.sql

{{ config(
    materialized="table",
    unique_key="match_id"
) }}

with staging_data as (
    -- Select distinct match-level info from staging to avoid fanning out
    select distinct
        match_id,
        match_date,
        match_number,
        event_stage,
        match_type_number,
        venue, -- Need venue name for join
        city, -- Need city for join
        team_1, -- Need team name for join
        team_2, -- Need team name for join
        toss_winner, -- Need team name for join
        toss_decision,
        match_result,
        match_winner, -- Need team name for join
        won_by_runs,
        won_by_wickets,
        result_method,
        player_of_match_id, -- Already have ID
        umpire_1_id, -- Already have ID
        umpire_2_id, -- Already have ID
        tv_umpires_id, -- Already have ID
        match_referees_id, -- Already have ID
        reserve_umpires_id, -- Already have ID
        
        -- Columns needed for event_id join
        event_name,
        season,
        match_type,
        gender,
        overs_limit,
        team_type,
        balls_per_over

    from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }}
),

joined_dims as (
    select 
        stg.match_id,
        
        -- Foreign Keys from Dimensions
        ev.event_id,
        dt.date_key as match_date_key,
        vn.venue_id,
        t1.team_id as team1_id,
        t2.team_id as team2_id,
        tw.team_id as toss_winner_team_id,
        win.team_id as winner_team_id,
        stg.player_of_match_id, -- Assuming this is the correct FK
        stg.umpire_1_id, -- Assuming this is the correct FK
        stg.umpire_2_id, -- Assuming this is the correct FK
        stg.tv_umpires_id, -- Assuming this is the correct FK
        stg.match_referees_id as match_referee_id, -- Renamed for consistency
        stg.reserve_umpires_id as reserve_umpire_id, -- Renamed for consistency

        -- Match Attributes from Staging
        stg.match_number,
        stg.event_stage,
        stg.match_type_number,
        stg.toss_decision,
        stg.match_result,
        stg.won_by_runs,
        stg.won_by_wickets,
        stg.result_method

    from staging_data stg
    -- Join dim_dates
    left join {{ ref("dim_dates") }} dt on stg.match_date = dt.full_date
    -- Join dim_events
    left join {{ ref("dim_events") }} ev on 
        {{ dbt_utils.generate_surrogate_key([
            "stg.event_name",
            "stg.season",
            "stg.match_type",
            "stg.gender",
            "stg.overs_limit",
            "stg.team_type",
            "stg.balls_per_over"
        ]) }} = ev.event_id
    -- Join dim_venues
    left join {{ ref("dim_venues") }} vn on 
        {{ dbt_utils.generate_surrogate_key([
            "stg.venue",
            "stg.city"
        ]) }} = vn.venue_id
    -- Join dim_teams for team 1
    left join {{ ref("dim_teams") }} t1 on 
        {{ dbt_utils.generate_surrogate_key([
            "stg.team_1",
            "stg.team_type"
        ]) }} = t1.team_id
    -- Join dim_teams for team 2
    left join {{ ref("dim_teams") }} t2 on 
        {{ dbt_utils.generate_surrogate_key([
            "stg.team_2",
            "stg.team_type"
        ]) }} = t2.team_id
    -- Join dim_teams for toss winner
    left join {{ ref("dim_teams") }} tw on 
        {{ dbt_utils.generate_surrogate_key([
            "stg.toss_winner",
            "stg.team_type"
        ]) }} = tw.team_id
    -- Join dim_teams for match winner
    left join {{ ref("dim_teams") }} win on 
        {{ dbt_utils.generate_surrogate_key([
            "stg.match_winner",
            "stg.team_type"
        ]) }} = win.team_id
    -- Note: Joins for player_of_match and officials are not needed here as we use the IDs directly from staging.
    -- Ensure dim_players and dim_officials are populated correctly before joining in facts/marts.
)

select * from joined_dims

