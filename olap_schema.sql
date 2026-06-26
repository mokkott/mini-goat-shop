drop table if exists fact_rental          cascade;
drop table if exists fact_sales           cascade;
drop table if exists bridge_order_goat    cascade;
drop table if exists dim_product          cascade;
drop table if exists dim_product_category cascade;
drop table if exists dim_goat             cascade;
drop table if exists dim_breed            cascade;
drop table if exists dim_customer         cascade;
drop table if exists dim_date             cascade;

create table dim_date (
    date_key      int          primary key,
    full_date     date         not null unique,
    day_of_week   smallint     not null,
    day_name      varchar(10)  not null,
    day_of_month  smallint     not null,
    month_num     smallint     not null,
    month_name    varchar(10)  not null,
    quarter       smallint     not null,
    year          smallint     not null,
    is_weekend    boolean      not null
);

create table dim_breed (
    breed_key       serial       primary key,
    breed_code      varchar(20)  not null unique,
    breed_name      varchar(100) not null,
    size_category   varchar(20)  not null,
    origin_country  varchar(100)
);

create table dim_goat (
    goat_key        serial       primary key,
    goat_code       varchar(20)  not null,
    breed_key       int          not null references dim_breed(breed_key),
    name            varchar(100) not null,
    birth_date      date         not null,
    gender          varchar(10)  not null,
    color           varchar(50),
    health_status   varchar(30)  not null,
    available       boolean      not null,
    -- scd type 2 tracking columns
    valid_from      date         not null,
    valid_to        date,
    is_current      boolean      not null default true
);

create index idx_dim_goat_code    on dim_goat(goat_code);
create index idx_dim_goat_current on dim_goat(goat_code, is_current);

create table dim_customer (
    customer_key      serial       primary key,
    customer_code     varchar(20)  not null unique,
    email             varchar(150) not null,
    first_name        varchar(80)  not null,
    last_name         varchar(80)  not null,
    city              varchar(80),
    registration_date date         not null
);

create table dim_product_category (
    category_key         serial       primary key,
    category_code        varchar(20)  not null unique,
    category_name        varchar(100) not null,
    parent_category_code varchar(20),
    parent_category_name varchar(100)
);

create table dim_product (
    product_key      serial        primary key,
    product_code     varchar(20)   not null unique,
    category_key     int           not null references dim_product_category(category_key),
    product_name     varchar(150)  not null,
    unit_price       numeric(10,2) not null,
    unit             varchar(20)   not null
);

create table bridge_order_goat (
    bridge_key    serial       primary key,
    order_code    varchar(20)  not null,
    goat_key      int          not null references dim_goat(goat_key),
    weight_factor numeric(5,4) not null default 1.0
);

create index idx_bridge_order on bridge_order_goat(order_code);

create table fact_sales (
    sales_key         serial        primary key,
    order_code        varchar(20)   not null,
    order_line_code   varchar(20)   not null unique,
    date_key          int           not null references dim_date(date_key),
    customer_key      int           not null references dim_customer(customer_key),
    product_key       int           references dim_product(product_key),
    goat_key          int           references dim_goat(goat_key),
    line_type         varchar(10)   not null check (line_type in ('product','goat')),
    quantity          int           not null,
    unit_price        numeric(10,2) not null,
    line_total        numeric(12,2) not null,
    payment_method    varchar(30)   not null,
    order_status      varchar(30)   not null
);

create index idx_fact_sales_date     on fact_sales(date_key);
create index idx_fact_sales_customer on fact_sales(customer_key);
create index idx_fact_sales_product  on fact_sales(product_key);

create table fact_rental (
    rental_key        serial        primary key,
    rental_code       varchar(20)   not null unique,
    start_date_key    int           not null references dim_date(date_key),
    end_date_key      int           not null references dim_date(date_key),
    customer_key      int           not null references dim_customer(customer_key),
    goat_key          int           not null references dim_goat(goat_key),
    event_type        varchar(50)   not null,
    rental_days       int           not null,
    rental_price      numeric(10,2) not null,
    rental_status     varchar(20)   not null
);

create index idx_fact_rental_date     on fact_rental(start_date_key);
create index idx_fact_rental_customer on fact_rental(customer_key);
create index idx_fact_rental_goat     on fact_rental(goat_key);
