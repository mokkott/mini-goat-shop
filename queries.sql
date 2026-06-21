SELECT
    g.goat_code,
    g.name,
    b.breed_name,
    b.size_category,
    g.gender,
    g.color,
    g.health_status,
    DATE_PART('year', AGE(g.birth_date)) || ' y ' ||
    DATE_PART('month', AGE(g.birth_date)) || ' m'  AS age
FROM goat g
JOIN breed b ON b.breed_code = g.breed_code
WHERE g.available = TRUE
ORDER BY b.breed_name, g.name;


SELECT
    c.customer_code,
    c.first_name || ' ' || c.last_name   AS customer_name,
    c.email,
    COALESCE(sales.total_sales, 0)        AS sales_total,
    COALESCE(rent.total_rentals, 0)       AS rentals_total,
    COALESCE(sales.total_sales, 0)
    + COALESCE(rent.total_rentals, 0)     AS grand_total,
    COALESCE(sales.order_count, 0)        AS orders,
    COALESCE(rent.rental_count, 0)        AS rentals
FROM customer c
LEFT JOIN (
    SELECT oh.customer_code,
           COUNT(DISTINCT oh.order_code)  AS order_count,
           SUM(ol.line_total)             AS total_sales
    FROM   order_header oh
    JOIN   order_line   ol ON ol.order_code = oh.order_code
    WHERE  oh.status <> 'cancelled'
    GROUP  BY oh.customer_code
) sales ON sales.customer_code = c.customer_code
LEFT JOIN (
    SELECT r.customer_code,
           COUNT(*)         AS rental_count,
           SUM(rental_price) AS total_rentals
    FROM   rental r
    WHERE  r.status <> 'cancelled'
    GROUP  BY r.customer_code
) rent ON rent.customer_code = c.customer_code
ORDER BY grand_total DESC;




SELECT
    TO_CHAR(period, 'YYYY-MM')    AS month,
    SUM(goat_revenue)             AS goat_sales,
    SUM(product_revenue)          AS product_sales,
    SUM(rental_revenue)           AS rental_revenue,
    SUM(goat_revenue + product_revenue + rental_revenue) AS total_revenue
FROM (
    SELECT
        DATE_TRUNC('month', oh.order_date)              AS period,
        CASE WHEN ol.goat_code IS NOT NULL THEN ol.line_total ELSE 0 END AS goat_revenue,
        CASE WHEN ol.product_code IS NOT NULL THEN ol.line_total ELSE 0 END AS product_revenue,
        0                                               AS rental_revenue
    FROM order_line   ol
    JOIN order_header oh ON oh.order_code = ol.order_code
    WHERE oh.status <> 'cancelled'

    UNION ALL

    SELECT
        DATE_TRUNC('month', r.rental_date)              AS period,
        0, 0,
        r.rental_price
    FROM rental r
    WHERE r.status <> 'cancelled'
) src
GROUP BY period
ORDER BY period;




SELECT
    g.goat_code,
    g.name,
    b.breed_name,
    COUNT(r.rental_code)          AS times_rented,
    SUM(r.return_date - r.rental_date + 1) AS total_days_rented,
    SUM(r.rental_price)           AS total_rental_revenue,
    ROUND(AVG(r.rental_price),2)  AS avg_rental_price
FROM goat g
JOIN breed  b ON b.breed_code  = g.breed_code
LEFT JOIN rental r ON r.goat_code = g.goat_code AND r.status <> 'cancelled'
GROUP BY g.goat_code, g.name, b.breed_name
ORDER BY times_rented DESC, total_rental_revenue DESC;




SELECT
    COALESCE(parent.category_name, pc.category_name)  AS top_category,
    pc.category_name                                   AS sub_category,
    COUNT(DISTINCT p.product_code)                     AS distinct_products,
    SUM(ol.quantity)                                   AS units_sold,
    SUM(ol.line_total)                                 AS revenue
FROM order_line ol
JOIN product          p      ON p.product_code     = ol.product_code
JOIN product_category pc     ON pc.category_code   = p.category_code
LEFT JOIN product_category parent ON parent.category_code = pc.parent_category_code
JOIN order_header     oh     ON oh.order_code      = ol.order_code
WHERE ol.product_code IS NOT NULL
  AND oh.status <> 'cancelled'
GROUP BY COALESCE(parent.category_name, pc.category_name), pc.category_name
ORDER BY revenue DESC;




SELECT
    dd.year,
    dd.quarter,
    fs.line_type,
    COUNT(*)              AS transactions,
    SUM(fs.quantity)      AS units_sold,
    SUM(fs.line_total)    AS revenue,
    ROUND(AVG(fs.line_total),2) AS avg_transaction
FROM olap.fact_sales  fs
JOIN olap.dim_date    dd ON dd.date_key = fs.date_key
WHERE fs.order_status <> 'cancelled'
GROUP BY ROLLUP(dd.year, dd.quarter, fs.line_type)
ORDER BY dd.year NULLS LAST, dd.quarter NULLS LAST, fs.line_type NULLS LAST;




SELECT
    dd.year,
    dd.month_name,
    dd.month_num,
    fr.event_type,
    COUNT(*)                        AS bookings,
    SUM(fr.rental_days)             AS total_days,
    SUM(fr.rental_price)            AS revenue,
    ROUND(AVG(fr.rental_price),2)   AS avg_price_per_booking
FROM olap.fact_rental fr
JOIN olap.dim_date    dd ON dd.date_key = fr.start_date_key
WHERE fr.rental_status <> 'cancelled'
GROUP BY dd.year, dd.month_num, dd.month_name, fr.event_type
ORDER BY dd.year, dd.month_num, revenue DESC;




SELECT
    db.breed_name,
    db.size_category,
    COUNT(DISTINCT CASE WHEN fs.line_type = 'goat' THEN fs.order_code END) AS goats_sold,
    COALESCE(SUM(CASE WHEN fs.line_type = 'goat' THEN fs.line_total END), 0) AS sales_revenue,
    COUNT(DISTINCT fr.rental_code)   AS rental_bookings,
    COALESCE(SUM(fr.rental_price), 0) AS rental_revenue,
    COALESCE(SUM(CASE WHEN fs.line_type = 'goat' THEN fs.line_total END), 0)
    + COALESCE(SUM(fr.rental_price), 0) AS total_revenue
FROM olap.dim_breed db
JOIN olap.dim_goat  dg ON dg.breed_key = db.breed_key AND dg.is_current = TRUE
LEFT JOIN olap.fact_sales  fs ON fs.goat_key = dg.goat_key
LEFT JOIN olap.fact_rental fr ON fr.goat_key = dg.goat_key AND fr.rental_status <> 'cancelled'
GROUP BY db.breed_name, db.size_category
ORDER BY total_revenue DESC;



SELECT
    dc.customer_code,
    dc.first_name || ' ' || dc.last_name   AS customer_name,
    dc.city,
    EXTRACT(YEAR FROM dc.registration_date) AS cohort_year,
    COUNT(DISTINCT fs.order_code)           AS total_orders,
    COALESCE(SUM(fs.line_total), 0)         AS sales_ltv,
    COUNT(DISTINCT fr.rental_code)          AS total_rentals,
    COALESCE(SUM(fr.rental_price), 0)       AS rental_ltv,
    COALESCE(SUM(fs.line_total), 0)
    + COALESCE(SUM(fr.rental_price), 0)     AS lifetime_value
FROM olap.dim_customer dc
LEFT JOIN olap.fact_sales  fs ON fs.customer_key = dc.customer_key
                              AND fs.order_status <> 'cancelled'
LEFT JOIN olap.fact_rental fr ON fr.customer_key = dc.customer_key
                              AND fr.rental_status <> 'cancelled'
GROUP BY dc.customer_code, dc.first_name, dc.last_name, dc.city, dc.registration_date
ORDER BY lifetime_value DESC;



SELECT
    dd.year,
    dd.quarter,
    dpc.parent_category_name                         AS top_category,
    dpc.category_name                                AS sub_category,
    SUM(fs.line_total)                               AS revenue,
    ROUND(
        100.0 * SUM(fs.line_total)
        / SUM(SUM(fs.line_total)) OVER (PARTITION BY dd.year, dd.quarter),
    2)                                               AS pct_of_quarter_revenue
FROM olap.fact_sales         fs
JOIN olap.dim_date           dd  ON dd.date_key    = fs.date_key
JOIN olap.dim_product        dp  ON dp.product_key = fs.product_key
JOIN olap.dim_product_category dpc ON dpc.category_key = dp.category_key
WHERE fs.line_type     = 'product'
  AND fs.order_status <> 'cancelled'
GROUP BY dd.year, dd.quarter, dpc.parent_category_name, dpc.category_name
ORDER BY dd.year, dd.quarter, revenue DESC;
