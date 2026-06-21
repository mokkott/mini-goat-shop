SET search_path = olap, oltp, public;

INSERT INTO public.dim_date (date_key, full_date, day_of_week, day_name, day_of_month,
                           month_num, month_name, quarter, year, is_weekend)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT          AS date_key,
    d                                     AS full_date,
    EXTRACT(ISODOW FROM d)::SMALLINT      AS day_of_week,
    TO_CHAR(d, 'Day')                     AS day_name,
    EXTRACT(DAY   FROM d)::SMALLINT       AS day_of_month,
    EXTRACT(MONTH FROM d)::SMALLINT       AS month_num,
    TO_CHAR(d, 'Month')                   AS month_name,
    EXTRACT(QUARTER FROM d)::SMALLINT     AS quarter,
    EXTRACT(YEAR FROM d)::SMALLINT        AS year,
    EXTRACT(ISODOW FROM d) IN (6,7)       AS is_weekend
FROM generate_series('2021-01-01'::DATE, '2026-12-31'::DATE, '1 day') AS g(d)
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO public.dim_breed (breed_code, breed_name, size_category, origin_country)
SELECT b.breed_code, b.breed_name, b.size_category, b.origin_country
FROM   public.breed b
ON CONFLICT (breed_code) DO NOTHING;

INSERT INTO public.dim_goat
    (goat_code, breed_key, name, birth_date, gender, color,
     health_status, available, valid_from, valid_to, is_current)
SELECT
    g.goat_code,
    db.breed_key,
    g.name,
    g.birth_date,
    g.gender,
    g.color,
    g.health_status,
    g.available,
    CURRENT_DATE,
    NULL,
    TRUE
FROM public.goat g
JOIN public.dim_breed db ON db.breed_code = g.breed_code
WHERE NOT EXISTS (
    SELECT 1 FROM public.dim_goat dg WHERE dg.goat_code = g.goat_code
);

UPDATE public.dim_goat dg
SET    valid_to   = CURRENT_DATE - 1,
       is_current = FALSE
FROM   public.goat g
WHERE  dg.goat_code  = g.goat_code
AND    dg.is_current = TRUE
AND    (dg.health_status <> g.health_status OR dg.available <> g.available);

INSERT INTO public.dim_goat
    (goat_code, breed_key, name, birth_date, gender, color,
     health_status, available, valid_from, valid_to, is_current)
SELECT
    g.goat_code,
    db.breed_key,
    g.name,
    g.birth_date,
    g.gender,
    g.color,
    g.health_status,
    g.available,
    CURRENT_DATE,
    NULL,
    TRUE
FROM public.goat g
JOIN public.dim_breed db ON db.breed_code = g.breed_code
WHERE NOT EXISTS (
    SELECT 1
    FROM   public.dim_goat dg
    WHERE  dg.goat_code  = g.goat_code
    AND    dg.is_current = TRUE
);

INSERT INTO public.dim_customer
    (customer_code, email, first_name, last_name, city, registration_date)
SELECT
    c.customer_code,
    c.email,
    c.first_name,
    c.last_name,
    TRIM(SPLIT_PART(c.address, ',', 2))   AS city,
    c.registration_date
FROM public.customer c
ON CONFLICT (customer_code) DO NOTHING;

INSERT INTO public.dim_product_category
    (category_code, category_name, parent_category_code, parent_category_name)
SELECT
    pc.category_code,
    pc.category_name,
    pc.parent_category_code,
    parent.category_name
FROM public.product_category pc
LEFT JOIN public.product_category parent ON parent.category_code = pc.parent_category_code
ON CONFLICT (category_code) DO NOTHING;

INSERT INTO public.dim_product (product_code, category_key, product_name, unit_price, unit)
SELECT
    p.product_code,
    dpc.category_key,
    p.product_name,
    p.unit_price,
    p.unit
FROM public.product p
JOIN public.dim_product_category dpc ON dpc.category_code = p.category_code
ON CONFLICT (product_code) DO NOTHING;

INSERT INTO public.fact_sales
    (order_code, order_line_code, date_key, customer_key, product_key,
     goat_key, line_type, quantity, unit_price, line_total,
     payment_method, order_status)
SELECT
    oh.order_code,
    ol.order_line_code,
    TO_CHAR(oh.order_date, 'YYYYMMDD')::INT   AS date_key,
    dc.customer_key,
    dp.product_key,
    dg.goat_key,
    CASE WHEN ol.goat_code IS NOT NULL THEN 'goat' ELSE 'product' END AS line_type,
    ol.quantity,
    ol.unit_price,
    ol.line_total,
    oh.payment_method,
    oh.status
FROM public.order_line    ol
JOIN public.order_header  oh ON oh.order_code    = ol.order_code
JOIN public.dim_customer  dc ON dc.customer_code = oh.customer_code
LEFT JOIN public.dim_product dp ON dp.product_code = ol.product_code
LEFT JOIN public.dim_goat    dg ON dg.goat_code    = ol.goat_code AND dg.is_current = TRUE
ON CONFLICT (order_line_code) DO NOTHING;

INSERT INTO public.bridge_order_goat (order_code, goat_key, weight_factor)
SELECT
    ol.order_code,
    dg.goat_key,
    1.0 / COUNT(*) OVER (PARTITION BY ol.order_code) AS weight_factor
FROM public.order_line ol
JOIN public.dim_goat dg ON dg.goat_code = ol.goat_code AND dg.is_current = TRUE
WHERE ol.goat_code IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM public.bridge_order_goat b
    WHERE  b.order_code = ol.order_code AND b.goat_key = dg.goat_key
);

INSERT INTO public.fact_rental
    (rental_code, start_date_key, end_date_key, customer_key, goat_key,
     event_type, rental_days, rental_price, rental_status)
SELECT
    r.rental_code,
    TO_CHAR(r.rental_date,  'YYYYMMDD')::INT AS start_date_key,
    TO_CHAR(r.return_date,  'YYYYMMDD')::INT AS end_date_key,
    dc.customer_key,
    dg.goat_key,
    r.event_type,
    (r.return_date - r.rental_date + 1)      AS rental_days,
    r.rental_price,
    r.status
FROM public.rental r
JOIN public.dim_customer dc ON dc.customer_code = r.customer_code
JOIN public.dim_goat     dg ON dg.goat_code     = r.goat_code AND dg.is_current = TRUE
ON CONFLICT (rental_code) DO NOTHING;

SELECT 'dim_date'             AS tbl, COUNT(*) AS rows FROM public.dim_date
UNION ALL SELECT 'dim_breed',          COUNT(*) FROM public.dim_breed
UNION ALL SELECT 'dim_goat',           COUNT(*) FROM public.dim_goat
UNION ALL SELECT 'dim_customer',       COUNT(*) FROM public.dim_customer
UNION ALL SELECT 'dim_product_cat',    COUNT(*) FROM public.dim_product_category
UNION ALL SELECT 'dim_product',        COUNT(*) FROM public.dim_product
UNION ALL SELECT 'bridge_order_goat',  COUNT(*) FROM public.bridge_order_goat
UNION ALL SELECT 'fact_sales',         COUNT(*) FROM public.fact_sales
UNION ALL SELECT 'fact_rental',        COUNT(*) FROM public.fact_rental;
