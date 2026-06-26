drop table if exists stg_breed;
drop table if exists stg_goat;
drop table if exists stg_product_category;
drop table if exists stg_product;
drop table if exists stg_customer;
drop table if exists stg_order_header;
drop table if exists stg_order_line;
drop table if exists stg_rental;

create temp table stg_breed (
    breed_code text, breed_name text, size_category text,
    origin_country text, description text
);
create temp table stg_goat (
    goat_code text, breed_code text, name text, birth_date text,
    gender text, color text, health_status text, available text
);
create temp table stg_product_category (
    category_code text, category_name text, parent_category_code text
);
create temp table stg_product (
    product_code text, category_code text, product_name text,
    description text, unit_price text, unit text
);
create temp table stg_customer (
    customer_code text, email text, first_name text, last_name text,
    phone text, address text, registration_date text
);
create temp table stg_order_header (
    order_code text, customer_code text, order_date text,
    status text, payment_method text, total_amount text
);
create temp table stg_order_line (
    order_line_code text, order_code text, goat_code text,
    product_code text, quantity text, unit_price text
);
create temp table stg_rental (
    rental_code text, customer_code text, goat_code text,
    rental_date text, return_date text, event_type text,
    rental_price text, status text
);

copy stg_breed            from 'D:/university/SQL/minigoats/breeds.csv'             with (format csv, header true);
copy stg_goat             from 'D:/university/SQL/minigoats/goats.csv'              with (format csv, header true);
copy stg_product_category from 'D:/university/SQL/minigoats/product_categories.csv' with (format csv, header true);
copy stg_product          from 'D:/university/SQL/minigoats/products.csv'           with (format csv, header true);
copy stg_customer         from 'D:/university/SQL/minigoats/customers.csv'          with (format csv, header true);
copy stg_order_header     from 'D:/university/SQL/minigoats/orders.csv'             with (format csv, header true);
copy stg_order_line       from 'D:/university/SQL/minigoats/order_lines.csv'        with (format csv, header true);
copy stg_rental           from 'D:/university/SQL/minigoats/rentals.csv'            with (format csv, header true);


insert into breed (breed_code, breed_name, size_category, origin_country, description)
select breed_code, breed_name, size_category,
       nullif(origin_country,''), nullif(description,'')
from stg_breed
on conflict (breed_code) do nothing;

insert into goat (goat_code, breed_code, name, birth_date, gender, color, health_status, available)
select goat_code, breed_code, name, birth_date::date, gender,
       nullif(color,''), health_status, available::boolean
from stg_goat
on conflict (goat_code) do nothing;

insert into product_category (category_code, category_name, parent_category_code)
select category_code, category_name, nullif(parent_category_code,'')
from stg_product_category
where nullif(parent_category_code,'') is null
on conflict (category_code) do nothing;

insert into product_category (category_code, category_name, parent_category_code)
select category_code, category_name, nullif(parent_category_code,'')
from stg_product_category
where nullif(parent_category_code,'') is not null
on conflict (category_code) do nothing;

insert into product (product_code, category_code, product_name, description, unit_price, unit)
select product_code, category_code, product_name,
       nullif(description,''), unit_price::numeric, unit
from stg_product
on conflict (product_code) do nothing;

insert into customer (customer_code, email, first_name, last_name, phone, address, registration_date)
select customer_code, email, first_name, last_name,
       nullif(phone,''), nullif(address,''), registration_date::date
from stg_customer
on conflict (customer_code) do nothing;

insert into order_header (order_code, customer_code, order_date, status, payment_method, total_amount)
select order_code, customer_code, order_date::date, status,
       payment_method, total_amount::numeric
from stg_order_header
on conflict (order_code) do nothing;

insert into order_line (order_line_code, order_code, goat_code, product_code, quantity, unit_price)
select order_line_code, order_code, nullif(goat_code,''),
       nullif(product_code,''), quantity::int, unit_price::numeric
from stg_order_line
on conflict (order_line_code) do nothing;

insert into rental (rental_code, customer_code, goat_code, rental_date, return_date, event_type, rental_price, status)
select rental_code, customer_code, goat_code, rental_date::date,
       return_date::date, event_type, rental_price::numeric, status
from stg_rental
on conflict (rental_code) do nothing;

select 'breed'        as таблица, count(*) as строк from breed
union all select 'goat',         count(*) from goat
union all select 'product_cat',  count(*) from product_category
union all select 'product',      count(*) from product
union all select 'customer',     count(*) from customer
union all select 'order_header', count(*) from order_header
union all select 'order_line',   count(*) from order_line
union all select 'rental',       count(*) from rental;
