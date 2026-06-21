-- ============================================================
-- MINI GOAT SHOP — Load data from CSV to OLTP (PostgreSQL)
-- Rerunnable: INSERT ... ON CONFLICT DO NOTHING
-- Run from psql: \i 02_load_data.sql
-- Set the path variable below to your CSV folder before running
-- ============================================================

-- Helper: adjust this path to the folder containing the CSV files
-- Windows example: C:/projects/mini_goat_shop/02_data
-- Linux/Mac:       /home/user/mini_goat_shop/02_data
\set csv_dir '/home/claude/mini_goat_shop/02_data'

-- --------------------------------------------------------
-- TEMP staging tables (dropped at the end of this session)
-- --------------------------------------------------------

DROP TABLE IF EXISTS stg_breed;
DROP TABLE IF EXISTS stg_goat;
DROP TABLE IF EXISTS stg_product_category;
DROP TABLE IF EXISTS stg_product;
DROP TABLE IF EXISTS stg_customer;
DROP TABLE IF EXISTS stg_order_header;
DROP TABLE IF EXISTS stg_order_line;
DROP TABLE IF EXISTS stg_rental;

CREATE TEMP TABLE stg_breed (
    breed_code       TEXT,
    breed_name       TEXT,
    size_category    TEXT,
    origin_country   TEXT,
    description      TEXT
);

CREATE TEMP TABLE stg_goat (
    goat_code      TEXT,
    breed_code     TEXT,
    name           TEXT,
    birth_date     TEXT,
    gender         TEXT,
    color          TEXT,
    health_status  TEXT,
    available      TEXT
);

CREATE TEMP TABLE stg_product_category (
    category_code        TEXT,
    category_name        TEXT,
    parent_category_code TEXT
);

CREATE TEMP TABLE stg_product (
    product_code  TEXT,
    category_code TEXT,
    product_name  TEXT,
    description   TEXT,
    unit_price    TEXT,
    unit          TEXT
);

CREATE TEMP TABLE stg_customer (
    customer_code     TEXT,
    email             TEXT,
    first_name        TEXT,
    last_name         TEXT,
    phone             TEXT,
    address           TEXT,
    registration_date TEXT
);

CREATE TEMP TABLE stg_order_header (
    order_code     TEXT,
    customer_code  TEXT,
    order_date     TEXT,
    status         TEXT,
    payment_method TEXT,
    total_amount   TEXT
);

CREATE TEMP TABLE stg_order_line (
    order_line_code TEXT,
    order_code      TEXT,
    goat_code       TEXT,
    product_code    TEXT,
    quantity        TEXT,
    unit_price      TEXT
);

CREATE TEMP TABLE stg_rental (
    rental_code   TEXT,
    customer_code TEXT,
    goat_code     TEXT,
    rental_date   TEXT,
    return_date   TEXT,
    event_type    TEXT,
    rental_price  TEXT,
    status        TEXT
);

-- --------------------------------------------------------
-- Load CSV → staging (COPY with HEADER)
-- --------------------------------------------------------

\copy stg_breed             FROM :'csv_dir'/breeds.csv           WITH (FORMAT csv, HEADER true);
\copy stg_goat              FROM :'csv_dir'/goats.csv            WITH (FORMAT csv, HEADER true);
\copy stg_product_category  FROM :'csv_dir'/product_categories.csv WITH (FORMAT csv, HEADER true);
\copy stg_product           FROM :'csv_dir'/products.csv         WITH (FORMAT csv, HEADER true);
\copy stg_customer          FROM :'csv_dir'/customers.csv        WITH (FORMAT csv, HEADER true);
\copy stg_order_header      FROM :'csv_dir'/orders.csv           WITH (FORMAT csv, HEADER true);
\copy stg_order_line        FROM :'csv_dir'/order_lines.csv      WITH (FORMAT csv, HEADER true);
\copy stg_rental            FROM :'csv_dir'/rentals.csv          WITH (FORMAT csv, HEADER true);

-- --------------------------------------------------------
-- Insert staging → target (ON CONFLICT DO NOTHING = rerunnable)
-- --------------------------------------------------------

-- 1. breed
INSERT INTO breed (breed_code, breed_name, size_category, origin_country, description)
SELECT breed_code,
       breed_name,
       size_category,
       NULLIF(origin_country,''),
       NULLIF(description,'')
FROM   stg_breed
ON CONFLICT (breed_code) DO NOTHING;

-- 2. goat
INSERT INTO goat (goat_code, breed_code, name, birth_date, gender, color, health_status, available)
SELECT goat_code,
       breed_code,
       name,
       birth_date::DATE,
       gender,
       NULLIF(color,''),
       health_status,
       available::BOOLEAN
FROM   stg_goat
ON CONFLICT (goat_code) DO NOTHING;

-- 3. product_category — load roots first, then children
-- Roots (no parent)
INSERT INTO product_category (category_code, category_name, parent_category_code)
SELECT category_code, category_name, NULLIF(parent_category_code,'')
FROM   stg_product_category
WHERE  NULLIF(parent_category_code,'') IS NULL
ON CONFLICT (category_code) DO NOTHING;

-- Children
INSERT INTO product_category (category_code, category_name, parent_category_code)
SELECT category_code, category_name, NULLIF(parent_category_code,'')
FROM   stg_product_category
WHERE  NULLIF(parent_category_code,'') IS NOT NULL
ON CONFLICT (category_code) DO NOTHING;

-- 4. product
INSERT INTO product (product_code, category_code, product_name, description, unit_price, unit)
SELECT product_code,
       category_code,
       product_name,
       NULLIF(description,''),
       unit_price::NUMERIC,
       unit
FROM   stg_product
ON CONFLICT (product_code) DO NOTHING;

-- 5. customer
INSERT INTO customer (customer_code, email, first_name, last_name, phone, address, registration_date)
SELECT customer_code,
       email,
       first_name,
       last_name,
       NULLIF(phone,''),
       NULLIF(address,''),
       registration_date::DATE
FROM   stg_customer
ON CONFLICT (customer_code) DO NOTHING;

-- 6. order_header
INSERT INTO order_header (order_code, customer_code, order_date, status, payment_method, total_amount)
SELECT order_code,
       customer_code,
       order_date::DATE,
       status,
       payment_method,
       total_amount::NUMERIC
FROM   stg_order_header
ON CONFLICT (order_code) DO NOTHING;

-- 7. order_line
INSERT INTO order_line (order_line_code, order_code, goat_code, product_code, quantity, unit_price)
SELECT order_line_code,
       order_code,
       NULLIF(goat_code,''),
       NULLIF(product_code,''),
       quantity::INT,
       unit_price::NUMERIC
FROM   stg_order_line
ON CONFLICT (order_line_code) DO NOTHING;

-- 8. rental
INSERT INTO rental (rental_code, customer_code, goat_code, rental_date, return_date, event_type, rental_price, status)
SELECT rental_code,
       customer_code,
       goat_code,
       rental_date::DATE,
       return_date::DATE,
       event_type,
       rental_price::NUMERIC,
       status
FROM   stg_rental
ON CONFLICT (rental_code) DO NOTHING;

-- --------------------------------------------------------
-- Summary
-- --------------------------------------------------------
SELECT 'breed'        AS tbl, COUNT(*) FROM breed
UNION ALL SELECT 'goat',         COUNT(*) FROM goat
UNION ALL SELECT 'product_cat',  COUNT(*) FROM product_category
UNION ALL SELECT 'product',      COUNT(*) FROM product
UNION ALL SELECT 'customer',     COUNT(*) FROM customer
UNION ALL SELECT 'order_header', COUNT(*) FROM order_header
UNION ALL SELECT 'order_line',   COUNT(*) FROM order_line
UNION ALL SELECT 'rental',       COUNT(*) FROM rental;
