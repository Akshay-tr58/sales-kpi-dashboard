-- FACT: one row per order line (numbers only) – hidden duplicate removed
CREATE OR REPLACE VIEW fact_sales AS
WITH ranked AS (
    SELECT o.*,
           ROW_NUMBER() OVER (
               PARTITION BY order_id, order_date, ship_date, ship_mode, customer_id,
                            product_id, postal_code, sales, quantity, discount, profit
               ORDER BY row_id) AS rn
    FROM orders o
)
SELECT row_id, order_id, order_date, ship_date, ship_mode,
       customer_id, product_id, postal_code,
       sales, quantity, discount, profit
FROM ranked
WHERE rn = 1;

-- DIMENSION: customers (who?)
CREATE OR REPLACE VIEW dim_customer AS
SELECT DISTINCT ON (customer_id) customer_id, customer_name, segment
FROM orders
ORDER BY customer_id, row_id;

-- DIMENSION: products (what?)
CREATE OR REPLACE VIEW dim_product AS
SELECT DISTINCT ON (product_id) product_id, product_name, category, sub_category
FROM orders
ORDER BY product_id, row_id;

-- DIMENSION: location (where?)
CREATE OR REPLACE VIEW dim_location AS
SELECT DISTINCT ON (postal_code) postal_code, city, state, region, country
FROM orders
ORDER BY postal_code, row_id;

-- DIMENSION: calendar (when?) – one row per day
CREATE OR REPLACE VIEW dim_date AS
SELECT d::date                        AS date,
       EXTRACT(YEAR FROM d)::int      AS year,
       EXTRACT(QUARTER FROM d)::int   AS quarter,
       EXTRACT(MONTH FROM d)::int     AS month,
       TO_CHAR(d, 'Mon')              AS month_name,
       TO_CHAR(d, 'YYYY-MM')          AS year_month
FROM generate_series(
        (SELECT MIN(order_date) FROM orders)::timestamp,
        (SELECT MAX(ship_date)  FROM orders)::timestamp,
        INTERVAL '1 day') AS d;

-- CHECK: row counts
SELECT 'fact_sales' AS view_name, COUNT(*) FROM fact_sales
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product',  COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_location', COUNT(*) FROM dim_location
UNION ALL SELECT 'dim_date',     COUNT(*) FROM dim_date;