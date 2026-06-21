DROP TABLE IF EXISTS stg_breed;
DROP TABLE IF EXISTS stg_goat;
DROP TABLE IF EXISTS stg_product_category;
DROP TABLE IF EXISTS stg_product;
DROP TABLE IF EXISTS stg_customer;
DROP TABLE IF EXISTS stg_order_header;
DROP TABLE IF EXISTS stg_order_line;
DROP TABLE IF EXISTS stg_rental;

CREATE TEMP TABLE stg_breed (
    breed_code TEXT, breed_name TEXT, size_category TEXT,
    origin_country TEXT, description TEXT
);
CREATE TEMP TABLE stg_goat (
    goat_code TEXT, breed_code TEXT, name TEXT, birth_date TEXT,
    gender TEXT, color TEXT, health_status TEXT, available TEXT
);
CREATE TEMP TABLE stg_product_category (
    category_code TEXT, category_name TEXT, parent_category_code TEXT
);
CREATE TEMP TABLE stg_product (
    product_code TEXT, category_code TEXT, product_name TEXT,
    description TEXT, unit_price TEXT, unit TEXT
);
CREATE TEMP TABLE stg_customer (
    customer_code TEXT, email TEXT, first_name TEXT, last_name TEXT,
    phone TEXT, address TEXT, registration_date TEXT
);
CREATE TEMP TABLE stg_order_header (
    order_code TEXT, customer_code TEXT, order_date TEXT,
    status TEXT, payment_method TEXT, total_amount TEXT
);
CREATE TEMP TABLE stg_order_line (
    order_line_code TEXT, order_code TEXT, goat_code TEXT,
    product_code TEXT, quantity TEXT, unit_price TEXT
);
CREATE TEMP TABLE stg_rental (
    rental_code TEXT, customer_code TEXT, goat_code TEXT,
    rental_date TEXT, return_date TEXT, event_type TEXT,
    rental_price TEXT, status TEXT
);

COPY stg_breed            FROM 'D:/university/SQL/minigoats/breeds.csv'            WITH (FORMAT csv, HEADER true);
COPY stg_goat             FROM 'D:/university/SQL/minigoats/goats.csv'             WITH (FORMAT csv, HEADER true);
COPY stg_product_category FROM 'D:/university/SQL/minigoats/product_categories.csv' WITH (FORMAT csv, HEADER true);
COPY stg_product          FROM 'D:/university/SQL/minigoats/products.csv'          WITH (FORMAT csv, HEADER true);
COPY stg_customer         FROM 'D:/university/SQL/minigoats/customers.csv'         WITH (FORMAT csv, HEADER true);
COPY stg_order_header     FROM 'D:/university/SQL/minigoats/orders.csv'            WITH (FORMAT csv, HEADER true);
COPY stg_order_line       FROM 'D:/university/SQL/minigoats/order_lines.csv'       WITH (FORMAT csv, HEADER true);
COPY stg_rental           FROM 'D:/university/SQL/minigoats/rentals.csv'           WITH (FORMAT csv, HEADER true);


INSERT INTO breed (breed_code, breed_name, size_category, origin_country, description)
SELECT breed_code, breed_name, size_category,
       NULLIF(origin_country,''), NULLIF(description,'')
FROM stg_breed
ON CONFLICT (breed_code) DO NOTHING;

INSERT INTO goat (goat_code, breed_code, name, birth_date, gender, color, health_status, available)
SELECT goat_code, breed_code, name, birth_date::DATE, gender,
       NULLIF(color,''), health_status, available::BOOLEAN
FROM stg_goat
ON CONFLICT (goat_code) DO NOTHING;

INSERT INTO product_category (category_code, category_name, parent_category_code)
SELECT category_code, category_name, NULLIF(parent_category_code,'')
FROM stg_product_category
WHERE NULLIF(parent_category_code,'') IS NULL
ON CONFLICT (category_code) DO NOTHING;

INSERT INTO product_category (category_code, category_name, parent_category_code)
SELECT category_code, category_name, NULLIF(parent_category_code,'')
FROM stg_product_category
WHERE NULLIF(parent_category_code,'') IS NOT NULL
ON CONFLICT (category_code) DO NOTHING;

INSERT INTO product (product_code, category_code, product_name, description, unit_price, unit)
SELECT product_code, category_code, product_name,
       NULLIF(description,''), unit_price::NUMERIC, unit
FROM stg_product
ON CONFLICT (product_code) DO NOTHING;

INSERT INTO customer (customer_code, email, first_name, last_name, phone, address, registration_date)
SELECT customer_code, email, first_name, last_name,
       NULLIF(phone,''), NULLIF(address,''), registration_date::DATE
FROM stg_customer
ON CONFLICT (customer_code) DO NOTHING;

INSERT INTO order_header (order_code, customer_code, order_date, status, payment_method, total_amount)
SELECT order_code, customer_code, order_date::DATE, status,
       payment_method, total_amount::NUMERIC
FROM stg_order_header
ON CONFLICT (order_code) DO NOTHING;

INSERT INTO order_line (order_line_code, order_code, goat_code, product_code, quantity, unit_price)
SELECT order_line_code, order_code, NULLIF(goat_code,''),
       NULLIF(product_code,''), quantity::INT, unit_price::NUMERIC
FROM stg_order_line
ON CONFLICT (order_line_code) DO NOTHING;

INSERT INTO rental (rental_code, customer_code, goat_code, rental_date, return_date, event_type, rental_price, status)
SELECT rental_code, customer_code, goat_code, rental_date::DATE,
       return_date::DATE, event_type, rental_price::NUMERIC, status
FROM stg_rental
ON CONFLICT (rental_code) DO NOTHING;

SELECT 'breed'        AS таблица, COUNT(*) AS строк FROM breed
UNION ALL SELECT 'goat',         COUNT(*) FROM goat
UNION ALL SELECT 'product_cat',  COUNT(*) FROM product_category
UNION ALL SELECT 'product',      COUNT(*) FROM product
UNION ALL SELECT 'customer',     COUNT(*) FROM customer
UNION ALL SELECT 'order_header', COUNT(*) FROM order_header
UNION ALL SELECT 'order_line',   COUNT(*) FROM order_line
UNION ALL SELECT 'rental',       COUNT(*) FROM rental;
