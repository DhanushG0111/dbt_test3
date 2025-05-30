-- models/facts/fct_deliveries.sql

{{ config(
    materialized="incremental",
    unique_key="delivery_key",
 
) }}
   -- Add partitioning/clustering for performance if applicable to your warehouse (e.g., Snowflake)
    -- partition_by={"field": "match_date", "data_type": "date"},
    -- cluster_by=["match_id", "batting_team_id"]
with staging_data as (
    select * from {{ ref("stg_cricket_ipl_db__all_ipl_match_data") }}
),

joined_dims as (
    select 
        stg.*,
        -- Get Foreign Keys from Dimensions
        ev.event_id,
        dt.date_key as match_date_key,
        vn.venue_id,
        btt.team_id as batting_team_id, -- Need to determine batting team based on innings/teams
        bwt.team_id as bowling_team_id, -- Need to determine bowling team based on innings/teams
        bat.player_id as batter_id, -- Assuming staging batter name is ID
        bwl.player_id as bowler_id, -- Assuming staging bowler name is ID
        ns.player_id as non_striker_id, -- Assuming staging non-striker name is ID
        wpo.player_id as wicket_player_out_id, -- Assuming staging wicket_player_out name is ID
        wf1.player_id as wicket_fielder1_id, -- Assuming staging wicket_fielder_1 name is ID
        wf2.player_id as wicket_fielder2_id -- Assuming staging wicket_fielder_2 name is ID

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
    -- Join dim_players for batter
    left join {{ ref("dim_players") }} bat on stg.batter = bat.player_name -- Assumes name is unique identifier, use ID if available
    -- Join dim_players for bowler
    left join {{ ref("dim_players") }} bwl on stg.bowler = bwl.player_name -- Assumes name is unique identifier, use ID if available
    -- Join dim_players for non-striker
    left join {{ ref("dim_players") }} ns on stg.non_striker = ns.player_name -- Assumes name is unique identifier, use ID if available
    -- Join dim_players for wicket_player_out
    left join {{ ref("dim_players") }} wpo on stg.wicket_player_out = wpo.player_name -- Assumes name is unique identifier, use ID if available
    -- Join dim_players for wicket_fielder1
    left join {{ ref("dim_players") }} wf1 on stg.wicket_fielder_1 = wf1.player_name -- Assumes name is unique identifier, use ID if available
    -- Join dim_players for wicket_fielder2
    left join {{ ref("dim_players") }} wf2 on stg.wicket_fielder_2 = wf2.player_name -- Assumes name is unique identifier, use ID if available
    -- Join dim_teams for batting team (logic depends on how batting team is identified per delivery)
    -- Placeholder: Need logic to determine batting team per delivery
    left join {{ ref("dim_teams") }} btt on 
        case 
            when stg.innings = 1 then {{ dbt_utils.generate_surrogate_key(["stg.team_1", "stg.team_type"]) }}
            when stg.innings = 2 then {{ dbt_utils.generate_surrogate_key(["stg.team_2", "stg.team_type"]) }}
            -- Add logic for super overs if needed
        end = btt.team_id
    -- Join dim_teams for bowling team (logic depends on how bowling team is identified per delivery)
    -- Placeholder: Need logic to determine bowling team per delivery
    left join {{ ref("dim_teams") }} bwt on 
        case 
            when stg.innings = 1 then {{ dbt_utils.generate_surrogate_key(["stg.team_2", "stg.team_type"]) }}
            when stg.innings = 2 then {{ dbt_utils.generate_surrogate_key(["stg.team_1", "stg.team_type"]) }}
            -- Add logic for super overs if needed
        end = bwt.team_id
),

final as (
    select
        -- Surrogate Key for the fact table
        {{ dbt_utils.generate_surrogate_key([
            "match_id",
            "innings",
            "over_in_innings",
            "delivery_in_over"
        ]) }} as delivery_key,

        -- Foreign Keys
        jd.match_id,
        jd.event_id,
        jd.match_date_key,
        jd.venue_id,
        jd.batting_team_id,
        jd.bowling_team_id,
        jd.batter_id,
        jd.bowler_id,
        jd.non_striker_id,
        jd.wicket_player_out_id,
        jd.wicket_fielder1_id,
        jd.wicket_fielder2_id,

        -- Degenerate Dimensions (already present in fact)
        jd.innings,
        jd.over_in_innings,
        jd.delivery_in_over,

        -- Measures
        jd.runs_batter,
        jd.runs_extras,
        jd.runs_total,
        jd.extras_wides,
        jd.extras_noballs,
        jd.extras_byes,
        jd.extras_legbyes,
        jd.extras_penalty,
        jd.target_remaining,
        jd.balls_remaining,

        -- Flags / Indicators
        jd.is_powerplay,
        (case when jd.wicket_kind is not null then true else false end) as is_wicket,
        jd.is_super_over,
        jd.is_review_umpires_call,

        -- Other Attributes (can be moved to dimensions if needed)
        jd.wicket_kind,
        jd.review_by,
        jd.review_umpire,
        jd.review_batter,
        jd.review_decision,
        jd.review_type

    from joined_dims jd
)

select * from final

{% if is_incremental() %}

  -- this filter will only be applied on an incremental run
  -- Assuming delivery_key is sufficient for incremental logic
  -- For date-based incrementals, filter on match_date_key or a timestamp column
  where delivery_key not in (select delivery_key from {{ this }})
  -- Example date-based incremental filter:
  -- where match_date_key >= (select max(match_date_key) from {{ this }})

{% endif %}

