{{ config (
    materialized='view'
) }}

with date_bounds as (
    select 
        min(match_date) as start_date,
        max(match_date) as end_date
    from {{ ref('stg_cricket_ipl_db__all_ipl_match_data') }}
),

date_spine as (
    select 
        dateadd(day, seq4(), start_date) as full_date
    from table(generator(rowcount => 10000)), date_bounds
    where dateadd(day, seq4(), start_date) <= end_date
),

date_attributes as (
    select
        full_date,
        year(full_date) as year,
        month(full_date) as month_number,
        day(full_date) as day_of_month,
        dayofweek(full_date) as day_of_week_number,
        dayofyear(full_date) as day_of_year,
        weekofyear(full_date) as week_of_year,
        quarter(full_date) as quarter_of_year,

        -- Day Name
        case dayofweek(full_date)
            when 1 then 'Sunday'
            when 2 then 'Monday'
            when 3 then 'Tuesday'
            when 4 then 'Wednesday'
            when 5 then 'Thursday'
            when 6 then 'Friday'
            when 7 then 'Saturday'
        end as day_name,

        -- Month Name
        case month(full_date)
            when 1 then 'January'
            when 2 then 'February'
            when 3 then 'March'
            when 4 then 'April'
            when 5 then 'May'
            when 6 then 'June'
            when 7 then 'July'
            when 8 then 'August'
            when 9 then 'September'
            when 10 then 'October'
            when 11 then 'November'
            when 12 then 'December'
        end as month_name
    from date_spine
)

select 
    to_number(to_char(full_date, 'YYYYMMDD')) as date_key,
    *
from date_attributes
order by full_date
