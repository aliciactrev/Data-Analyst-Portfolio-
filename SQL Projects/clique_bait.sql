--Clique Bait Analysis 
-- Part B1 how many users are there
select 
	count(distinct user_id)
from clique_bait.users
limit 10; 
-- Part b2 How many cookies does each user have on average?

select
	sum(num_cookies) 
	,count(distinct user_id)
	,round(sum(num_cookies)/count(distinct user_id),2) as avg_cookie_count
from
(select 
	user_id
	,count(cookie_id) as num_cookies
from clique_bait.users
group by 1
 ) a0
 ;
-- What is the unique number of visits by all users per month 
-- we have the visit_id from the events table
-- cookie_id can be connected to the users table from the events table

select 
	date_trunc('month',event_date)::date as event_month
	,count(distinct visit_id) as unique_visit_count
from 
(select
	u.user_id
	,u.cookie_id
	,e.visit_id
	,e.event_time::date as event_date
from
	clique_bait.events e
inner join clique_bait.users u 
on e.cookie_id = u.cookie_id
order by 4
) a1
group by 1;

-- B4: What is the number of events for each event type
select
	e.event_type
	,ei.event_name
	,count(e.event_type)
from clique_bait.events e
inner join clique_bait.event_identifier ei
on e.event_type = ei.event_type
group by 1,2
order by 1; 

-- What is the percentage of visits which have a purchase event 
-- be careful that window functions calculate values for every row, not once per group 
-- The code below refers to What % of all ations were purchases
select 
	event_name
	,total_visits as total_visits_per_event
	,sum(total_visits) over() as total_visits 
	,round(round(total_visits/sum(total_visits) over(),4)*100,2) as perc_visit
from 
(
select
	 ei.event_name
	,count(e.visit_id) as total_visits
from clique_bait.events e
inner join clique_bait.event_identifier ei
on e.event_type = ei.event_type
group by 1
	) a3
	;
-- this code below refers to what % of visits resulted in a purchase
select count(distinct e.visit_id) * 100
/ (select count(distinct visit_id) from clique_bait.events)
from clique_bait.events e 
join clique_bait.event_identifier ei on e.event_type = ei.event_type
where ei.event_name = 'Purchase';

select
	round(sum(purchase_event)::numeric/count(*)::numeric *100,2) as purchase_perc
from 
(
select 
	e.visit_id
	,sum(case when event_name ='Purchase' then 1 else  0 end) as purchase_event
from clique_bait.events e
inner join clique_bait.event_identifier ei 
on ei.event_type = e.event_type
group by 1
) a3;
-- b6 
--What is the percentage of visits which view the checkout page 
--but do not have a purchase event?
--select event_name from clique_bait.event_identifier;
select
	round(sum(case when checkout_count = 1 and purchase_count = 0 then 1 else 0 end)::numeric/count(*)::numeric *100,2)
	as perc_no_purchase
from 
(select 
 e.visit_id
 ,sum(case when ei.event_name = 'Page View' and ph.page_name = 'Checkout' then 1 else 0 end) as checkout_count
 ,sum(case when ei.event_name = 'Purchase' and ph.page_name = 'Confirmation' then 1 else 0 end) as purchase_count
from clique_bait.events e 
inner join clique_bait.event_identifier ei 
on e.event_type = ei.event_type
inner join clique_bait.page_hierarchy ph 
on e.page_id  = ph.page_id
group by 1
) t0
;
-- What are the top 3 pages by number of views
select 
	ph.page_name
	,count(*)
from 
clique_bait.events e
inner join clique_bait.page_hierarchy ph
on e.page_id = ph.page_id
where e.event_type = 1
group by 1 
order by 2 desc 
limit 3 ;
-- What is the number of views and cart adds for each product category?
-- Part d. final question
with visit_start_time as 
(
select 
 distinct visit_id
 ,u.user_id
 ,min(event_time)::date as earliest_visit
from 
clique_bait.events e 
inner join clique_bait.users u 
on e.cookie_id = u.cookie_id
group by 1,2
 )
 ,page_views 
 as (
 select 
 	distinct visit_id
    ,sum(case when ei.event_name = 'Page View' then 1 else 0 end) as page_views
 from clique_bait.events e
 inner join clique_bait.event_identifier ei
 on e.event_type = ei.event_type
group by 1
   )
  ,add_c 
  as (
 select 
 	distinct e.visit_id
    ,sum(case when ei.event_name = 'Add to Cart' then 1 else 0 end) as cart_adds
 from clique_bait.events e
 inner join clique_bait.event_identifier ei 
 on e.event_type = ei.event_type
 group by 1
    
    )
 ,purchase_exist 
 as (
 select
 	visit_id
    ,case when ei.event_name = 'Purchase' then 1 else 0 end as purchase_flag
 from clique_bait.events e 
 inner join clique_bait.event_identifier ei 
 on e.event_type = ei.event_type
 )
 ,filtered_visit 
 as 
 (
 select 
 	a0.visit_id
 	,ci.campaign_name
    ,a0.earliest_visit
   
 from 
 clique_bait.campaign_identifier ci 
 inner join visit_start_time as a0 
 on a0.earliest_visit between ci.start_date and ci.end_date) 
 
 
   , ad_clicks 
   as (
 select 
 e.visit_id
 ,sum(case when ei.event_name = 'Ad Impression' then 1 else 0 end) as ad_count
 from clique_bait.events e
 inner join clique_bait.event_identifier ei 
 on e.event_type = ei.event_type
 group by 1
   )
   

 ,cart_list 
 as ( 
select
  e.visit_id
  ,string_agg(case when ei.event_name ='Add to Cart' then ph.page_name end
			 , ', ' order by e.sequence_number) as cart_products
from clique_bait.events e
inner join clique_bait.event_identifier ei 
on ei.event_type = e.event_type 
inner join clique_bait.page_hierarchy ph 
on ph.page_id = e.page_id
group by 1
order by 1 asc
)

select
 vst.visit_id
 ,vst.user_id
 ,vst.earliest_visit
 ,cl.cart_products
 ,pv.page_views as page_view_count
 ,add_c.cart_adds as add_to_cart_count
 ,pe.purchase_flag as purchase_count
 ,fv.campaign_name as campaign_name
 ,ac.ad_count as add_click_count
from visit_start_time vst
left join cart_list cl 
on vst.visit_id = cl.visit_id
left join page_views pv
on vst.visit_id = pv.visit_id
left join add_c 
on add_c.visit_id= vst.visit_id
left join purchase_exist pe
on pe.visit_id = vst.visit_id
left join filtered_visit fv
on fv.visit_id = vst.visit_id
left join ad_clicks ac 
on ac.visit_id = vst.visit_id
where vst.visit_id = '0826dc'
	