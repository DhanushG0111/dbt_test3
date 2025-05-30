-- models/marts/analytics/mart_player_match_performance.sql
{{ config(materialized="table") }}

with
    batting_agg as (select * from {{ ref("int_player_batting_match_aggregates") }}),

    bowling_agg as (select * from {{ ref("int_player_bowling_match_aggregates") }}),

    matches as (select * from {{ ref("dim_matches") }}),

    teams as (select * from {{ ref("dim_teams") }}),

    players as (select * from {{ ref("dim_players") }}),

    events as (select * from {{ ref("dim_events") }}),

    venues as (select * from {{ ref("dim_venues") }}),

    dates as (select * from {{ ref("dim_dates") }}),

    -- Combine batting and bowling stats per player per match
    -- Use a full outer join in case a player only batted or only bowled in a match
    combined_performance as (
        select
            coalesce(b.match_id, bo.match_id) as match_id,
            coalesce(b.batter_id, bo.bowler_id) as player_id,
            coalesce(b.batting_team_id, bo.bowling_team_id) as team_id,  -- Assuming player plays for one team per match
            coalesce(b.match_date_key, bo.match_date_key) as match_date_key,

            -- Batting Stats
            b.total_runs,
            b.balls_faced,
            b.fours as batting_fours,
            b.sixes as batting_sixes,
            b.is_out,
            b.strike_rate as batting_strike_rate,
            b.scored_hundred,
            b.scored_fifty,

            -- Bowling Stats
            bo.balls_bowled,
            bo.overs_bowled_decimal,
            bo.runs_conceded,
            bo.wickets_taken,
            bo.dot_balls,
            bo.fours_conceded as bowling_fours_conceded,
            bo.sixes_conceded as bowling_sixes_conceded,
            bo.wides,
            bo.noballs,
            bo.economy_rate,
            bo.bowling_average,
            bo.bowling_strike_rate

        from batting_agg b
        full outer join
            bowling_agg bo on b.match_id = bo.match_id and b.batter_id = bo.bowler_id  -- Join on player
    ),

    -- Join with dimensions for context
    final as (
        select
            -- Match Info
            cp.match_id,
            m.match_number,
            m.event_stage,
            d.full_date as match_date,
            d.year as match_year,
            d.month_name as match_month,
            d.day_name as match_day_name,
            v.venue_name,
            v.city as venue_city,
            e.event_name,
            e.season,
            e.match_type,

            -- Player Info
            cp.player_id,
            p.player_name,

            -- Team Info
            cp.team_id,
            t.team_name,
            -- Identify opponent team
            case
                when cp.team_id = m.team1_id
                then m.team2_id
                when cp.team_id = m.team2_id
                then m.team1_id
                else null
            end as opponent_team_id,
            opp_t.team_name as opponent_team_name,

            -- Performance Metrics
            cp.total_runs,
            cp.balls_faced,
            cp.batting_fours,
            cp.batting_sixes,
            cp.is_out,
            cp.batting_strike_rate,
            cp.scored_hundred,
            cp.scored_fifty,
            cp.balls_bowled,
            cp.overs_bowled_decimal,
            cp.runs_conceded,
            cp.wickets_taken,
            cp.dot_balls,
            cp.bowling_fours_conceded,
            cp.bowling_sixes_conceded,
            cp.wides,
            cp.noballs,
            cp.economy_rate,
            cp.bowling_average,
            cp.bowling_strike_rate,

            -- Match Result Context
            m.match_result,
            m.winner_team_id,
            win_t.team_name as winner_team_name,
            (cp.team_id = m.winner_team_id) as is_winning_team_player

        from combined_performance cp
        left join players p on cp.player_id = p.player_id
        left join teams t on cp.team_id = t.team_id
        left join matches m on cp.match_id = m.match_id
        left join dates d on cp.match_date_key = d.date_key
        left join venues v on m.venue_id = v.venue_id
        left join events e on m.event_id = e.event_id
        left join teams opp_t on opponent_team_id = opp_t.team_id
        left join teams win_t on m.winner_team_id = win_t.team_id
    )

select *
from final
