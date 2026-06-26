drop table if exists rental           cascade;
drop table if exists order_line       cascade;
drop table if exists order_header     cascade;
drop table if exists product          cascade;
drop table if exists product_category cascade;
drop table if exists customer         cascade;
drop table if exists goat             cascade;
drop table if exists breed            cascade;

create table breed (
    breed_code       varchar(20)  primary key,
    breed_name       varchar(100) not null unique,
    size_category    varchar(20)  not null check (size_category in ('mini','dwarf','standard')),
    origin_country   varchar(100),
    description      text
);

create table goat (
    goat_code      varchar(20)  primary key,
    breed_code     varchar(20)  not null references breed(breed_code),
    name           varchar(100) not null,
    birth_date     date         not null,
    gender         varchar(10)  not null check (gender in ('male','female')),
    color          varchar(50),
    health_status  varchar(30)  not null default 'healthy'
                                check (health_status in ('healthy','vaccinated','quarantine')),
    available      boolean      not null default true
);

create table product_category (
    category_code        varchar(20)  primary key,
    category_name        varchar(100) not null,
    parent_category_code varchar(20)  references product_category(category_code)
);

create table product (
    product_code  varchar(20)   primary key,
    category_code varchar(20)   not null references product_category(category_code),
    product_name  varchar(150)  not null,
    description   text,
    unit_price    numeric(10,2) not null check (unit_price > 0),
    unit          varchar(20)   not null default 'pcs'
);

create table customer (
    customer_code     varchar(20)  primary key,
    email             varchar(150) not null unique,
    first_name        varchar(80)  not null,
    last_name         varchar(80)  not null,
    phone             varchar(30),
    address           text,
    registration_date date         not null default current_date
);

create table order_header (
    order_code     varchar(20)   primary key,
    customer_code  varchar(20)   not null references customer(customer_code),
    order_date     date          not null default current_date,
    status         varchar(30)   not null default 'new'
                                 check (status in ('new','processing','shipped','delivered','cancelled')),
    payment_method varchar(30)   not null check (payment_method in ('card','cash','transfer')),
    total_amount   numeric(12,2) not null check (total_amount >= 0)
);

create table order_line (
    order_line_code varchar(20)   primary key,
    order_code      varchar(20)   not null references order_header(order_code),
    goat_code       varchar(20)   references goat(goat_code),
    product_code    varchar(20)   references product(product_code),
    quantity        int           not null default 1 check (quantity > 0),
    unit_price      numeric(10,2) not null check (unit_price > 0),
    line_total      numeric(12,2) generated always as (quantity * unit_price) stored,
    constraint chk_item check (
        (goat_code is not null and product_code is null)
        or (goat_code is null and product_code is not null)
    )
);

create table rental (
    rental_code   varchar(20)   primary key,
    customer_code varchar(20)   not null references customer(customer_code),
    goat_code     varchar(20)   not null references goat(goat_code),
    rental_date   date          not null,
    return_date   date          not null,
    event_type    varchar(50)   not null check (event_type in ('photoshoot','birthday','petting_zoo','corporate','other')),
    rental_price  numeric(10,2) not null check (rental_price > 0),
    status        varchar(20)   not null default 'booked'
                                check (status in ('booked','active','completed','cancelled')),
    constraint chk_dates check (return_date >= rental_date)
);

create index idx_goat_breed        on goat(breed_code);
create index idx_goat_available    on goat(available);
create index idx_order_customer    on order_header(customer_code);
create index idx_order_date        on order_header(order_date);
create index idx_order_line_order  on order_line(order_code);
create index idx_rental_customer   on rental(customer_code);
create index idx_rental_goat       on rental(goat_code);
create index idx_rental_date       on rental(rental_date);
create index idx_product_category  on product(category_code);
