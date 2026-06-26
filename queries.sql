select
    g.goat_code,
    g.name,
    b.breed_name,
    b.size_category,
    g.gender,
    g.color,
    g.health_status,
    date_part('year', age(g.birth_date)) || ' y ' ||
    date_part('month', age(g.birth_date)) || ' m'  as age
from goat g
join breed b on b.breed_code = g.breed_code
where g.available = true
order by b.breed_name, g.name;


select
    c.customer_code,
    c.first_name || ' ' || c.last_name   as customer_name,
    c.email,
    coalesce(sales.total_sales, 0)        as sales_total,
    coalesce(rent.total_rentals, 0)       as rentals_total,
    coalesce(sales.total_sales, 0)
    + coalesce(rent.total_rentals, 0)     as grand_total,
    coalesce(sales.order_count, 0)        as orders,
    coalesce(rent.rental_count, 0)        as rentals
from customer c
left join (
    select oh.customer_code,
           count(distinct oh.order_code)  as order_count,
           sum(ol.line_total)             as total_sales
    from   order_header oh
    join   order_line   ol on ol.order_code = oh.order_code
    where  oh.status <> 'cancelled'
    group  by oh.customer_code
) sales on sales.customer_code = c.customer_code
left join (
    select r.customer_code,
           count(*)          as rental_count,
           sum(rental_price) as total_rentals
    from   rental r
    where  r.status <> 'cancelled'
    group  by r.customer_code
) rent on rent.customer_code = c.customer_code
order by grand_total desc;


select
    to_char(period, 'YYYY-MM')    as month,
    sum(goat_revenue)             as goat_sales,
    sum(product_revenue)          as product_sales,
    sum(rental_revenue)           as rental_revenue,
    sum(goat_revenue + product_revenue + rental_revenue) as total_revenue
from (
    select
        date_trunc('month', oh.order_date)              as period,
        case when ol.goat_code is not null then ol.line_total else 0 end as goat_revenue,
        case when ol.product_code is not null then ol.line_total else 0 end as product_revenue,
        0                                               as rental_revenue
    from order_line   ol
    join order_header oh on oh.order_code = ol.order_code
    where oh.status <> 'cancelled'

    union all

    select
        date_trunc('month', r.rental_date)              as period,
        0, 0,
        r.rental_price
    from rental r
    where r.status <> 'cancelled'
) src
group by period
order by period;


select
    g.goat_code,
    g.name,
    b.breed_name,
    count(r.rental_code)          as times_rented,
    sum(r.return_date - r.rental_date + 1) as total_days_rented,
    sum(r.rental_price)           as total_rental_revenue,
    round(avg(r.rental_price),2)  as avg_rental_price
from goat g
join breed  b on b.breed_code  = g.breed_code
left join rental r on r.goat_code = g.goat_code and r.status <> 'cancelled'
group by g.goat_code, g.name, b.breed_name
order by times_rented desc, total_rental_revenue desc;


select
    coalesce(parent.category_name, pc.category_name)  as top_category,
    pc.category_name                                   as sub_category,
    count(distinct p.product_code)                     as distinct_products,
    sum(ol.quantity)                                   as units_sold,
    sum(ol.line_total)                                 as revenue
from order_line ol
join product          p      on p.product_code     = ol.product_code
join product_category pc     on pc.category_code   = p.category_code
left join product_category parent on parent.category_code = pc.parent_category_code
join order_header     oh     on oh.order_code      = ol.order_code
where ol.product_code is not null
  and oh.status <> 'cancelled'
group by coalesce(parent.category_name, pc.category_name), pc.category_name
order by revenue desc;


select
    dd.year,
    dd.quarter,
    fs.line_type,
    count(*)              as transactions,
    sum(fs.quantity)      as units_sold,
    sum(fs.line_total)    as revenue,
    round(avg(fs.line_total),2) as avg_transaction
from olap.fact_sales  fs
join olap.dim_date    dd on dd.date_key = fs.date_key
where fs.order_status <> 'cancelled'
group by rollup(dd.year, dd.quarter, fs.line_type)
order by dd.year nulls last, dd.quarter nulls last, fs.line_type nulls last;


select
    dd.year,
    dd.month_name,
    dd.month_num,
    fr.event_type,
    count(*)                        as bookings,
    sum(fr.rental_days)             as total_days,
    sum(fr.rental_price)            as revenue,
    round(avg(fr.rental_price),2)   as avg_price_per_booking
from olap.fact_rental fr
join olap.dim_date    dd on dd.date_key = fr.start_date_key
where fr.rental_status <> 'cancelled'
group by dd.year, dd.month_num, dd.month_name, fr.event_type
order by dd.year, dd.month_num, revenue desc;


select
    db.breed_name,
    db.size_category,
    count(distinct case when fs.line_type = 'goat' then fs.order_code end) as goats_sold,
    coalesce(sum(case when fs.line_type = 'goat' then fs.line_total end), 0) as sales_revenue,
    count(distinct fr.rental_code)    as rental_bookings,
    coalesce(sum(fr.rental_price), 0) as rental_revenue,
    coalesce(sum(case when fs.line_type = 'goat' then fs.line_total end), 0)
    + coalesce(sum(fr.rental_price), 0) as total_revenue
from olap.dim_breed db
join olap.dim_goat  dg on dg.breed_key = db.breed_key and dg.is_current = true
left join olap.fact_sales  fs on fs.goat_key = dg.goat_key
left join olap.fact_rental fr on fr.goat_key = dg.goat_key and fr.rental_status <> 'cancelled'
group by db.breed_name, db.size_category
order by total_revenue desc;


select
    dc.customer_code,
    dc.first_name || ' ' || dc.last_name   as customer_name,
    dc.city,
    extract(year from dc.registration_date) as cohort_year,
    count(distinct fs.order_code)           as total_orders,
    coalesce(sum(fs.line_total), 0)         as sales_ltv,
    count(distinct fr.rental_code)          as total_rentals,
    coalesce(sum(fr.rental_price), 0)       as rental_ltv,
    coalesce(sum(fs.line_total), 0)
    + coalesce(sum(fr.rental_price), 0)     as lifetime_value
from olap.dim_customer dc
left join olap.fact_sales  fs on fs.customer_key = dc.customer_key
                              and fs.order_status <> 'cancelled'
left join olap.fact_rental fr on fr.customer_key = dc.customer_key
                              and fr.rental_status <> 'cancelled'
group by dc.customer_code, dc.first_name, dc.last_name, dc.city, dc.registration_date
order by lifetime_value desc;


select
    dd.year,
    dd.quarter,
    dpc.parent_category_name                         as top_category,
    dpc.category_name                                as sub_category,
    sum(fs.line_total)                               as revenue,
    round(
        100.0 * sum(fs.line_total)
        / sum(sum(fs.line_total)) over (partition by dd.year, dd.quarter),
    2)                                               as pct_of_quarter_revenue
from olap.fact_sales         fs
join olap.dim_date           dd  on dd.date_key    = fs.date_key
join olap.dim_product        dp  on dp.product_key = fs.product_key
join olap.dim_product_category dpc on dpc.category_key = dp.category_key
where fs.line_type     = 'product'
  and fs.order_status <> 'cancelled'
group by dd.year, dd.quarter, dpc.parent_category_name, dpc.category_name
order by dd.year, dd.quarter, revenue desc;
