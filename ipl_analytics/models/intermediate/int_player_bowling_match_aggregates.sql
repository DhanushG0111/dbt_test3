-- models/intermediate/int_player_bowling_match_aggregates.sql

with deliveries as (
    select * from {{ ref("fct_deliveries") }}
),

matches as (
    select * from {{ ref("dim_matches") }}
),

players as (
    select * from {{ ref("dim_players") }}
),

match_bowling_stats as (
    select
        d.match_id,
        d.bowling_team_id,
        d.bowler_id,
        m.match_date_key,
        
        count(*) as balls_bowled,
        sum(d.runs_total) as runs_conceded,
        sum(case when d.is_wicket = true and d.wicket_kind not in (
            -- Exclude run outs, retired hurt, etc. from bowler wickets
            'run out', 'retired hurt', 'obstructing the field', 'retired out'
            ) then 1 else 0 end) as wickets_taken,
        sum(case when d.runs_total = 0 then 1 else 0 end) as dot_balls,
        sum(case when d.runs_total = 4 then 1 else 0 end) as fours_conceded,
        sum(case when d.runs_total = 6 then 1 else 0 end) as sixes_conceded,
        sum(d.extras_wides) as wides,
        sum(d.extras_noballs) as noballs
        
    from deliveries d
    join matches m on d.match_id = m.match_id
    where d.bowler_id is not null
    group by 1, 2, 3, 4
),

-- Calculate overs bowled (integer division for full overs, handle remainder)
-- Note: Assumes 6 balls per over standard
overs_calculation as (
    select
        *,
        floor(balls_bowled / 6) as completed_overs,
        mod(balls_bowled, 6) as extra_balls,
        -- Format overs as X.Y (e.g., 3.2 overs)
        floor(balls_bowled / 6) + (mod(balls_bowled, 6) / 10.0) as overs_bowled_decimal
    from match_bowling_stats
)

select 
    oc.match_id,
    oc.match_date_key,
    oc.bowling_team_id,
    oc.bowler_id,
    p.player_name as bowler_name,
    oc.balls_bowled,
    oc.overs_bowled_decimal,
    oc.runs_conceded,
    oc.wickets_taken,
    oc.dot_balls,
    oc.fours_conceded,
    oc.sixes_conceded,
    oc.wides,
    oc.noballs,
    -- Calculate economy rate, handle division by zero (using balls bowled for precision)
    case 
        when oc.balls_bowled > 0 then round((oc.runs_conceded * 6.0) / oc.balls_bowled, 2)
        else 0 
    end as economy_rate,
    -- Calculate bowling average, handle division by zero
    case 
        when oc.wickets_taken > 0 then round(oc.runs_conceded * 1.0 / oc.wickets_taken, 2)
        else null -- Or 0, depending on preference for undefined average
    end as bowling_average,
    -- Calculate bowling strike rate, handle division by zero
    case 
        when oc.wickets_taken > 0 then round(oc.balls_bowled * 1.0 / oc.wickets_taken, 2)
        else null -- Or 0, depending on preference
    end as bowling_strike_rate

from overs_calculation oc
left join players p on oc.bowler_id = p.player_id

