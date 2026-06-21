DROP TABLE IF EXISTS fact_rental        CASCADE;
DROP TABLE IF EXISTS fact_sales         CASCADE;
DROP TABLE IF EXISTS bridge_order_goat  CASCADE;
DROP TABLE IF EXISTS dim_product        CASCADE;
DROP TABLE IF EXISTS dim_product_category CASCADE;
DROP TABLE IF EXISTS dim_goat           CASCADE;
DROP TABLE IF EXISTS dim_breed          CASCADE;
DROP TABLE IF EXISTS dim_customer       CASCADE;
DROP TABLE IF EXISTS dim_date           CASCADE;

CREATE TABLE dim_date (
    date_key      INT          PRIMARY KEY,   
    full_date     DATE         NOT NULL UNIQUE,
    day_of_week   SMALLINT     NOT NULL,       
    day_name      VARCHAR(10)  NOT NULL,
    day_of_month  SMALLINT     NOT NULL,
    month_num     SMALLINT     NOT NULL,
    month_name    VARCHAR(10)  NOT NULL,
    quarter       SMALLINT     NOT NULL,
    year          SMALLINT     NOT NULL,
    is_weekend    BOOLEAN      NOT NULL
);

CREATE TABLE dim_breed (
    breed_key       SERIAL       PRIMARY KEY,
    breed_code      VARCHAR(20)  NOT NULL UNIQUE,
    breed_name      VARCHAR(100) NOT NULL,
    size_category   VARCHAR(20)  NOT NULL,
    origin_country  VARCHAR(100)
);

CREATE TABLE dim_goat (
    goat_key        SERIAL       PRIMARY KEY,
    goat_code       VARCHAR(20)  NOT NULL,
    breed_key       INT          NOT NULL REFERENCES dim_breed(breed_key),
    name            VARCHAR(100) NOT NULL,
    birth_date      DATE         NOT NULL,
    gender          VARCHAR(10)  NOT NULL,
    color           VARCHAR(50),
    health_status   VARCHAR(30)  NOT NULL,
    available       BOOLEAN      NOT NULL,
    -- SCD Type 2 tracking columns
    valid_from      DATE         NOT NULL,
    valid_to        DATE,                     
    is_current      BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_dim_goat_code    ON dim_goat(goat_code);
CREATE INDEX idx_dim_goat_current ON dim_goat(goat_code, is_current);

CREATE TABLE dim_customer (
    customer_key      SERIAL       PRIMARY KEY,
    customer_code     VARCHAR(20)  NOT NULL UNIQUE,
    email             VARCHAR(150) NOT NULL,
    first_name        VARCHAR(80)  NOT NULL,
    last_name         VARCHAR(80)  NOT NULL,
    city              VARCHAR(80),            
    registration_date DATE         NOT NULL
);

CREATE TABLE dim_product_category (
    category_key         SERIAL       PRIMARY KEY,
    category_code        VARCHAR(20)  NOT NULL UNIQUE,
    category_name        VARCHAR(100) NOT NULL,
    parent_category_code VARCHAR(20),
    parent_category_name VARCHAR(100)
);

CREATE TABLE dim_product (
    product_key      SERIAL        PRIMARY KEY,
    product_code     VARCHAR(20)   NOT NULL UNIQUE,
    category_key     INT           NOT NULL REFERENCES dim_product_category(category_key),
    product_name     VARCHAR(150)  NOT NULL,
    unit_price       NUMERIC(10,2) NOT NULL,
    unit             VARCHAR(20)   NOT NULL
);

CREATE TABLE bridge_order_goat (
    bridge_key    SERIAL      PRIMARY KEY,
    order_code    VARCHAR(20) NOT NULL,
    goat_key      INT         NOT NULL REFERENCES dim_goat(goat_key),
    weight_factor NUMERIC(5,4) NOT NULL DEFAULT 1.0
);

CREATE INDEX idx_bridge_order ON bridge_order_goat(order_code);
CREATE TABLE fact_sales (
    sales_key         SERIAL        PRIMARY KEY,
    order_code        VARCHAR(20)   NOT NULL,
    order_line_code   VARCHAR(20)   NOT NULL UNIQUE,
    date_key          INT           NOT NULL REFERENCES dim_date(date_key),
    customer_key      INT           NOT NULL REFERENCES dim_customer(customer_key),
    product_key       INT           REFERENCES dim_product(product_key),
    goat_key          INT           REFERENCES dim_goat(goat_key),
    line_type         VARCHAR(10)   NOT NULL CHECK (line_type IN ('product','goat')),
    quantity          INT           NOT NULL,
    unit_price        NUMERIC(10,2) NOT NULL,
    line_total        NUMERIC(12,2) NOT NULL,
    payment_method    VARCHAR(30)   NOT NULL,
    order_status      VARCHAR(30)   NOT NULL
);

CREATE INDEX idx_fact_sales_date     ON fact_sales(date_key);
CREATE INDEX idx_fact_sales_customer ON fact_sales(customer_key);
CREATE INDEX idx_fact_sales_product  ON fact_sales(product_key);
CREATE TABLE fact_rental (
    rental_key        SERIAL        PRIMARY KEY,
    rental_code       VARCHAR(20)   NOT NULL UNIQUE,
    start_date_key    INT           NOT NULL REFERENCES dim_date(date_key),
    end_date_key      INT           NOT NULL REFERENCES dim_date(date_key),
    customer_key      INT           NOT NULL REFERENCES dim_customer(customer_key),
    goat_key          INT           NOT NULL REFERENCES dim_goat(goat_key),
    event_type        VARCHAR(50)   NOT NULL,
    rental_days       INT           NOT NULL,
    rental_price      NUMERIC(10,2) NOT NULL,
    rental_status     VARCHAR(20)   NOT NULL
);

CREATE INDEX idx_fact_rental_date     ON fact_rental(start_date_key);
CREATE INDEX idx_fact_rental_customer ON fact_rental(customer_key);
CREATE INDEX idx_fact_rental_goat     ON fact_rental(goat_key);
