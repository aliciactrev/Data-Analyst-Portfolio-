
-- convert the week_date to date format
drop materialized view if exists data_mart.clean_weekly_sales;
set datestyle = dmy
;

create materialized view data_mart.clean_weekly_sales as
select
	to_date(week_date,'DD/MM/YY') as clean_week_date
	,date_part('week', to_date(week_date, 'DD/MM/YY')) AS week_number
	,extract(month from  to_date(week_date,'DD/MM/YY')) as month_number
	,extract(year from to_date(week_date,'DD/MM/YY')) as calendar_year
	,region
	,platform
	,segment
	,substring(segment,'([0-9]{1,4})')::numeric as clean_segment_number
	,case when substring(segment,1,1)='C' then 'Couples' 
		  when substring(segment,1,1)='F' then 'Families' else 'unknown'
		  end as demographic_segment
	,case when substring(segment,'([0-9]{1,4})')::numeric = 1 then 'Young Adults'
	when substring(segment,'([0-9]{1,4})')::numeric = 2 then 'Middle Aged'
	when substring(segment,'([0-9]{1,4})')::numeric = 3 or substring(segment,'([0-9]{1,4})')::numeric = 3 then 'Retirees'
	else 'unknown' end as age_band 
	,customer_type
	,transactions
	,sales
	,round(sales::numeric/transactions::numeric,2) as avg_transactions 
from data_mart.weekly_sales;
--A1
select to_char(clean_week_date,'day') from data_mart.clean_weekly_sales
order by clean_week_date asc
;
--A2
with gen_week as (
    select generate_series(1,52) as week_number
)
select 
    c2.week_number
from 
    gen_week c2
left join data_mart.clean_weekly_sales c1
    on c1.week_number = c2.week_number
where c1.week_number is null
order by c2.week_number;
-- A3 how many total transactions were there for each year in the dataset

select
	calendar_year
	,count(*) as total_trx_count
	,sum(transactions) as total_trx
from data_mart.clean_weekly_sales
group by 1; 
-- total sales for each region for each month
select 
	region
	,calendar_year
	,month_number
	,sum(sales) as total_sales 
from data_mart.clean_weekly_sales
group by 1,2,3
order by calendar_year asc,month_number asc
limit 7;
--Question was vague: it's asking for the sum of transactions per platform
select
	platform
	,sum(transactions)
from data_mart.weekly_sales 
group by 1;
--% of sales for Retail vs Shopfiy for each month 
select 
	platform
	,calendar_year
	,month_number
	,round(sum(total_pf::numeric)/sum(total_sales_overall),3)*100 as perc_per_platform
from
(select
	platform
	,calendar_year
	,month_number
	,sum(sales) over(partition by platform, calendar_year,month_number order by calendar_year asc,month_number asc) as total_pf
 	,sum(sales) over(partition by calendar_year,month_number order by calendar_year asc, month_number asc) 
	as total_sales_overall
from data_mart.clean_weekly_sales
) as t0
group by 1,2,3
order by calendar_year asc,month_number asc;
-- What is the amount and percentage of sales by demographic for each year in the dataset
select
	demographic_segment
	,calendar_year
	,round(sum(sales_per_dem::numeric)/sum(sales_per_year::numeric),2)*100 as perc_per_dem
	,sales_per_dem
from(
select 
	demographic_segment
	,calendar_year
	,sum(sales) over(partition by demographic_segment,calendar_year order by calendar_year asc) as sales_per_dem
	,sum(sales) over(partition by calendar_year order by calendar_year asc) as sales_per_year
from data_mart.clean_weekly_sales 
) t1
group by 1,2,4
order by calendar_year asc;
-- which age_band and demographic values contribute the most to retail sales
select 
	age_band
	,demographic_segment
	,round(total_sales_age_demo/(sum(total_sales_age_demo) over()),2)*100 as total_sales_pc
from 
(select
	age_band
	,demographic_segment
	,sum(sales::numeric) as total_sales_age_demo
from data_mart.clean_weekly_sales
where platform='Retail'
group by 1,2) t2
order by total_sales_pc desc;
-- Can we use the avg_transaction column to find tthe average transaction size for each year for retail vs shopfiy
-- if not - how would you calculate it 
-- Answer no beecause it's based on each row. This would be wrong calculation

select
  calendar_year
  ,platform
  ,ROUND(sum(sales)::numeric / sum(transactions), 2) as avg_annual_transaction
from data_mart.clean_weekly_sales
group by calendar_year, platform
order by calendar_year, platform;

-- Part C Before and After Analysis 
-- We want to take the week_date value of 2020-06-15 as the baseline week as the "after_period"
-- dates befores this is noted as the "before_period"
-- we want percentage and actual value of sales 
select 
	time_period 
	,sum(sales) as total_sales 
	,lag(sum(sales)) over(order by time_period desc ) as prev_total_sales
	,sum(sales) - lag(sum(sales)) over(order by time_period desc) as sales_diff
	,round(nullif(sum(sales)/(lag(sum(sales)) over() ) - 1,0)*100,2) as rate_before_after
from 
(
select
	clean_week_date
	,week_number
	,case when week_number >= 21 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 28 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=21 and week_number <= 28
	and calendar_year::numeric = 2020
	) t4
group by 1
order by time_period desc;

-- What about the entire 12 weeks before and after (same logic as before)
-- week number: 25 
select 
	time_period 
	,sum(sales) as total_sales 
	,lag(sum(sales)) over(order by time_period desc ) as prev_total_sales
	,sum(sales) - lag(sum(sales)) over(order by time_period desc) as sales_diff
	,round(nullif(sum(sales)/(lag(sum(sales)) over() ) - 1,0)*100,2) as rate_before_after
from 
(
select
	clean_week_date
	,week_number
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >= 13 and week_number <= 36
	and calendar_year::numeric = 2020
	) t4
group by 1
order by time_period desc;

-- how do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019 
-- this is the for 4 week period difference across 2018,2019, and 2020
with p0 as 
(select 
	calendar_year
	,time_period
	,sum(sales)::numeric as total_sales
	,lag(sum(sales),1) over(partition by calendar_year order by time_period desc)::numeric as  prev_total_sales
	,sum(sales)::numeric - lag(sum(sales),1) over(partition by calendar_year order by time_period desc)::numeric as sales_diff
from
(
select
	calendar_year
	,case when week_number >= 21 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 28 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=21 and week_number <= 28
	and calendar_year::numeric in (2020,2019,2018)
) x1
group by 1,2
order by calendar_year asc, time_period desc
 )
select
	calendar_year
	,sales_diff
	,prev_total_sales
	,round(round(sales_diff/prev_total_sales,4)*100,2) as perc_sales_change
from p0
where sales_diff!=0;

-- 12 weeks difference across 2018, 2019, 2020
with p1 as (
select 
	calendar_year
	,time_period
	,sum(sales)::numeric as total_sales
	,lag(sum(sales),1) over(partition by calendar_year order by time_period desc)::numeric as  prev_total_sales
	,sum(sales)::numeric - lag(sum(sales),1) over(partition by calendar_year order by time_period desc)::numeric as sales_diff
from
(
select
	calendar_year
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=13 and week_number <= 36
	and calendar_year::numeric in (2020,2019,2018)
) x1
group by 1,2
order by calendar_year asc, time_period desc
 )
select
	calendar_year
	,sales_diff
	,prev_total_sales
	,round(round(sales_diff/prev_total_sales,4)*100,2) as perc_sales_change
from p1
where sales_diff!=0
;
-- Part D Bonus Question
-- Which areas of the business have the highest negative imapct in sales metrics performance
-- in 2020 for the 12 week before and after period 

-- by region 
with tt_0 as (
select
	calendar_year
	,region
	,platform
	,age_band
	,demographic_segment
	,customer_type
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=13 and week_number <= 36
	and calendar_year::numeric = 2020)

select
	region
	,total_sales
	,prev_tot_sales
	,total_sales-prev_tot_sales as diff_sales 
	,round(total_sales/prev_tot_sales -1,3)*100 as perc_diff_sales
from 
(select 
	region
	,time_period
	,sum(sales) as total_sales
	,lag(sum(sales),1) over(partition by region order by time_period desc) as prev_tot_sales
from tt_0
group by 1,2
order by 3,2 desc
 ) r0
 where prev_tot_sales is not null
	order by 5 asc; 
	
-- by platform
with tt_0 as (
select
	calendar_year
	,region
	,platform
	,age_band
	,demographic_segment
	,customer_type
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=13 and week_number <= 36
	and calendar_year::numeric = 2020)

select
	platform
	,total_sales
	,prev_tot_sales
	,total_sales-prev_tot_sales as diff_sales 
	,round(total_sales/prev_tot_sales -1,3)*100 as perc_diff_sales
from 
(select 
	platform
	,time_period
	,sum(sales) as total_sales
	,lag(sum(sales),1) over(partition by platform order by time_period desc) as prev_tot_sales
from tt_0
group by 1,2
order by 3,2 desc
 ) r0
 where prev_tot_sales is not null
	order by 5 asc; 
	
-- by age_band

with tt_0 as (
select
	calendar_year
	,region
	,platform
	,age_band
	,demographic_segment
	,customer_type
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=13 and week_number <= 36
	and calendar_year::numeric = 2020)

select
	age_band
	,total_sales
	,prev_tot_sales
	,total_sales-prev_tot_sales as diff_sales 
	,round(total_sales/prev_tot_sales -1,3)*100 as perc_diff_sales
from 
(select 
	age_band
	,time_period
	,sum(sales) as total_sales
	,lag(sum(sales),1) over(partition by age_band order by time_period desc) as prev_tot_sales
from tt_0
group by 1,2
order by 3,2 desc
 ) r0
 where prev_tot_sales is not null
	order by 5 asc; 
	
-- by demographic

with tt_0 as (
select
	calendar_year
	,region
	,platform
	,age_band
	,demographic_segment
	,customer_type
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=13 and week_number <= 36
	and calendar_year::numeric = 2020)

select
	platform
	,total_sales
	,prev_tot_sales
	,total_sales-prev_tot_sales as diff_sales 
	,round(total_sales/prev_tot_sales -1,3)*100 as perc_diff_sales
from 
(select 
	platform
	,time_period
	,sum(sales) as total_sales
	,lag(sum(sales),1) over(partition by platform order by time_period desc) as prev_tot_sales
from tt_0
group by 1,2
order by 3,2 desc
 ) r0
 where prev_tot_sales is not null
	order by 5 asc; 
	
-- by age_band

with tt_0 as (
select
	calendar_year
	,region
	,platform
	,age_band
	,demographic_segment
	,customer_type
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=13 and week_number <= 36
	and calendar_year::numeric = 2020)

select
	demographic_segment
	,total_sales
	,prev_tot_sales
	,total_sales-prev_tot_sales as diff_sales 
	,round(round(total_sales/prev_tot_sales -1,4)*100,2) as perc_diff_sales
from 
(select 
	demographic_segment
	,time_period
	,sum(sales) as total_sales
	,lag(sum(sales),1) over(partition by demographic_segment order by time_period desc) as prev_tot_sales
from tt_0
group by 1,2
order by 3,2 desc
 ) r0
 where prev_tot_sales is not null
	order by 5 asc; 
-- by customer_type
with tt_0 as (
select
	calendar_year
	,region
	,platform
	,age_band
	,demographic_segment
	,customer_type
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=13 and week_number <= 36
	and calendar_year::numeric = 2020)

select
	platform
	,total_sales
	,prev_tot_sales
	,total_sales-prev_tot_sales as diff_sales 
	,round(round(total_sales/prev_tot_sales -1,4)*100,2) as perc_diff_sales
from 
(select 
	platform
	,time_period
	,sum(sales) as total_sales
	,lag(sum(sales),1) over(partition by platform order by time_period desc) as prev_tot_sales
from tt_0
group by 1,2
order by 3,2 desc
 ) r0
 where prev_tot_sales is not null
	order by 5 asc; 
	
-- by age_band

with tt_0 as (
select
	calendar_year
	,region
	,platform
	,age_band
	,demographic_segment
	,customer_type
	,case when week_number >= 13 and week_number <=24 then 'before' 
		  when week_number >=25 and week_number <= 36 then 'after' end as time_period
	,sales::numeric
from data_mart.clean_weekly_sales
where week_number >=13 and week_number <= 36
	and calendar_year::numeric = 2020)

select
	customer_type
	,total_sales
	,prev_tot_sales
	,total_sales-prev_tot_sales as diff_sales 
	,round(round(total_sales/prev_tot_sales -1,4)*100,2) as perc_diff_sales
from 
(select 
	customer_type
	,time_period
	,sum(sales) as total_sales
	,lag(sum(sales),1) over(partition by customer_type order by time_period desc) as prev_tot_sales
from tt_0
group by 1,2
order by 3,2 desc
 ) r0
 where prev_tot_sales is not null
	order by 5 asc; 