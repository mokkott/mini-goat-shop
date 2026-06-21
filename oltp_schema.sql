DROP TABLE IF EXISTS rental       CASCADE;
DROP TABLE IF EXISTS order_line   CASCADE;
DROP TABLE IF EXISTS order_header CASCADE;
DROP TABLE IF EXISTS product      CASCADE;
DROP TABLE IF EXISTS product_category CASCADE;
DROP TABLE IF EXISTS customer     CASCADE;
DROP TABLE IF EXISTS goat         CASCADE;
DROP TABLE IF EXISTS breed        CASCADE;

CREATE TABLE breed (
    breed_code       VARCHAR(20)  PRIMARY KEY,
    breed_name       VARCHAR(100) NOT NULL UNIQUE,
    size_category    VARCHAR(20)  NOT NULL CHECK (size_category IN ('mini','dwarf','standard')),
    origin_country   VARCHAR(100),
    description      TEXT
);

CREATE TABLE goat (
    goat_code      VARCHAR(20)  PRIMARY KEY,
    breed_code     VARCHAR(20)  NOT NULL REFERENCES breed(breed_code),
    name           VARCHAR(100) NOT NULL,
    birth_date     DATE         NOT NULL,
    gender         VARCHAR(10)  NOT NULL CHECK (gender IN ('male','female')),
    color          VARCHAR(50),
    health_status  VARCHAR(30)  NOT NULL DEFAULT 'healthy'
                                CHECK (health_status IN ('healthy','vaccinated','quarantine')),
    available      BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE product_category (
    category_code        VARCHAR(20)  PRIMARY KEY,
    category_name        VARCHAR(100) NOT NULL,
    parent_category_code VARCHAR(20)  REFERENCES product_category(category_code)
);

CREATE TABLE product (
    product_code  VARCHAR(20)   PRIMARY KEY,
    category_code VARCHAR(20)   NOT NULL REFERENCES product_category(category_code),
    product_name  VARCHAR(150)  NOT NULL,
    description   TEXT,
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    unit          VARCHAR(20)   NOT NULL DEFAULT 'pcs'
);

CREATE TABLE customer (
    customer_code     VARCHAR(20)  PRIMARY KEY,
    email             VARCHAR(150) NOT NULL UNIQUE,
    first_name        VARCHAR(80)  NOT NULL,
    last_name         VARCHAR(80)  NOT NULL,
    phone             VARCHAR(30),
    address           TEXT,
    registration_date DATE         NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE order_header (
    order_code     VARCHAR(20)   PRIMARY KEY,
    customer_code  VARCHAR(20)   NOT NULL REFERENCES customer(customer_code),
    order_date     DATE          NOT NULL DEFAULT CURRENT_DATE,
    status         VARCHAR(30)   NOT NULL DEFAULT 'new'
                                 CHECK (status IN ('new','processing','shipped','delivered','cancelled')),
    payment_method VARCHAR(30)   NOT NULL CHECK (payment_method IN ('card','cash','transfer')),
    total_amount   NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0)
);

CREATE TABLE order_line (
    order_line_code VARCHAR(20)   PRIMARY KEY,
    order_code      VARCHAR(20)   NOT NULL REFERENCES order_header(order_code),
    goat_code       VARCHAR(20)   REFERENCES goat(goat_code),
    product_code    VARCHAR(20)   REFERENCES product(product_code),
    quantity        INT           NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    line_total      NUMERIC(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    CONSTRAINT chk_item CHECK (
        (goat_code IS NOT NULL AND product_code IS NULL)
        OR (goat_code IS NULL AND product_code IS NOT NULL)
    )
);

CREATE TABLE rental (
    rental_code   VARCHAR(20)   PRIMARY KEY,
    customer_code VARCHAR(20)   NOT NULL REFERENCES customer(customer_code),
    goat_code     VARCHAR(20)   NOT NULL REFERENCES goat(goat_code),
    rental_date   DATE          NOT NULL,
    return_date   DATE          NOT NULL,
    event_type    VARCHAR(50)   NOT NULL CHECK (event_type IN ('photoshoot','birthday','petting_zoo','corporate','other')),
    rental_price  NUMERIC(10,2) NOT NULL CHECK (rental_price > 0),
    status        VARCHAR(20)   NOT NULL DEFAULT 'booked'
                                CHECK (status IN ('booked','active','completed','cancelled')),
    CONSTRAINT chk_dates CHECK (return_date >= rental_date)
);

CREATE INDEX idx_goat_breed        ON goat(breed_code);
CREATE INDEX idx_goat_available    ON goat(available);
CREATE INDEX idx_order_customer    ON order_header(customer_code);
CREATE INDEX idx_order_date        ON order_header(order_date);
CREATE INDEX idx_order_line_order  ON order_line(order_code);
CREATE INDEX idx_rental_customer   ON rental(customer_code);
CREATE INDEX idx_rental_goat       ON rental(goat_code);
CREATE INDEX idx_rental_date       ON rental(rental_date);
CREATE INDEX idx_product_category  ON product(category_code);
