set search_path = olap, oltp, public;

insert into public.dim_date (date_key, full_date, day_of_week, day_name, day_of_month,
                           month_num, month_name, quarter, year, is_weekend)
select
    to_char(d, 'YYYYMMDD')::int          as date_key,
    d                                     as full_date,
    extract(isodow from d)::smallint      as day_of_week,
    to_char(d, 'Day')                     as day_name,
    extract(day   from d)::smallint       as day_of_month,
    extract(month from d)::smallint       as month_num,
    to_char(d, 'Month')                   as month_name,
    extract(quarter from d)::smallint     as quarter,
    extract(year from d)::smallint        as year,
    extract(isodow from d) in (6,7)       as is_weekend
from generate_series('2021-01-01'::date, '2026-12-31'::date, '1 day') as g(d)
on conflict (date_key) do nothing;

insert into public.dim_breed (breed_code, breed_name, size_category, origin_country)
select b.breed_code, b.breed_name, b.size_category, b.origin_country
from   public.breed b
on conflict (breed_code) do nothing;

insert into public.dim_goat
    (goat_code, breed_key, name, birth_date, gender, color,
     health_status, available, valid_from, valid_to, is_current)
select
    g.goat_code,
    db.breed_key,
    g.name,
    g.birth_date,
    g.gender,
    g.color,
    g.health_status,
    g.available,
    current_date,
    null,
    true
from public.goat g
join public.dim_breed db on db.breed_code = g.breed_code
where not exists (
    select 1 from public.dim_goat dg where dg.goat_code = g.goat_code
);

update public.dim_goat dg
set    valid_to   = current_date - 1,
       is_current = false
from   public.goat g
where  dg.goat_code  = g.goat_code
and    dg.is_current = true
and    (dg.health_status <> g.health_status or dg.available <> g.available);

insert into public.dim_goat
    (goat_code, breed_key, name, birth_date, gender, color,
     health_status, available, valid_from, valid_to, is_current)
select
    g.goat_code,
    db.breed_key,
    g.name,
    g.birth_date,
    g.gender,
    g.color,
    g.health_status,
    g.available,
    current_date,
    null,
    true
from public.goat g
join public.dim_breed db on db.breed_code = g.breed_code
where not exists (
    select 1
    from   public.dim_goat dg
    where  dg.goat_code  = g.goat_code
    and    dg.is_current = true
);

insert into public.dim_customer
    (customer_code, email, first_name, last_name, city, registration_date)
select
    c.customer_code,
    c.email,
    c.first_name,
    c.last_name,
    trim(split_part(c.address, ',', 2))   as city,
    c.registration_date
from public.customer c
on conflict (customer_code) do nothing;

insert into public.dim_product_category
    (category_code, category_name, parent_category_code, parent_category_name)
select
    pc.category_code,
    pc.category_name,
    pc.parent_category_code,
    parent.category_name
from public.product_category pc
left join public.product_category parent on parent.category_code = pc.parent_category_code
on conflict (category_code) do nothing;

insert into public.dim_product (product_code, category_key, product_name, unit_price, unit)
select
    p.product_code,
    dpc.category_key,
    p.product_name,
    p.unit_price,
    p.unit
from public.product p
join public.dim_product_category dpc on dpc.category_code = p.category_code
on conflict (product_code) do nothing;

insert into public.fact_sales
    (order_code, order_line_code, date_key, customer_key, product_key,
     goat_key, line_type, quantity, unit_price, line_total,
     payment_method, order_status)
select
    oh.order_code,
    ol.order_line_code,
    to_char(oh.order_date, 'YYYYMMDD')::int   as date_key,
    dc.customer_key,
    dp.product_key,
    dg.goat_key,
    case when ol.goat_code is not null then 'goat' else 'product' end as line_type,
    ol.quantity,
    ol.unit_price,
    ol.line_total,
    oh.payment_method,
    oh.status
from public.order_line    ol
join public.order_header  oh on oh.order_code    = ol.order_code
join public.dim_customer  dc on dc.customer_code = oh.customer_code
left join public.dim_product dp on dp.product_code = ol.product_code
left join public.dim_goat    dg on dg.goat_code    = ol.goat_code and dg.is_current = true
on conflict (order_line_code) do nothing;

insert into public.bridge_order_goat (order_code, goat_key, weight_factor)
select
    ol.order_code,
    dg.goat_key,
    1.0 / count(*) over (partition by ol.order_code) as weight_factor
from public.order_line ol
join public.dim_goat dg on dg.goat_code = ol.goat_code and dg.is_current = true
where ol.goat_code is not null
and not exists (
    select 1 from public.bridge_order_goat b
    where  b.order_code = ol.order_code and b.goat_key = dg.goat_key
);

insert into public.fact_rental
    (rental_code, start_date_key, end_date_key, customer_key, goat_key,
     event_type, rental_days, rental_price, rental_status)
select
    r.rental_code,
    to_char(r.rental_date,  'YYYYMMDD')::int as start_date_key,
    to_char(r.return_date,  'YYYYMMDD')::int as end_date_key,
    dc.customer_key,
    dg.goat_key,
    r.event_type,
    (r.return_date - r.rental_date + 1)      as rental_days,
    r.rental_price,
    r.status
from public.rental r
join public.dim_customer dc on dc.customer_code = r.customer_code
join public.dim_goat     dg on dg.goat_code     = r.goat_code and dg.is_current = true
on conflict (rental_code) do nothing;

select 'dim_date'             as tbl, count(*) as rows from public.dim_date
union all select 'dim_breed',          count(*) from public.dim_breed
union all select 'dim_goat',           count(*) from public.dim_goat
union all select 'dim_customer',       count(*) from public.dim_customer
union all select 'dim_product_cat',    count(*) from public.dim_product_category
union all select 'dim_product',        count(*) from public.dim_product
union all select 'bridge_order_goat',  count(*) from public.bridge_order_goat
union all select 'fact_sales',         count(*) from public.fact_sales
union all select 'fact_rental',        count(*) from public.fact_rental;
