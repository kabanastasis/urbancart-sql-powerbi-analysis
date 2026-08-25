-- UrbanCart - Data Quality & Validation Checks

-- Before starting the business analysis, I performed several
-- checks to validate the completeness, consistency and
-- reliability of the dataset.

-- 1. Row counts

SELECT COUNT(*) AS total_customers
FROM customers;

SELECT COUNT(*) AS total_products
FROM products;

SELECT COUNT(*) AS total_orders
FROM orders;

SELECT COUNT(*) AS total_order_items
FROM order_items;

SELECT COUNT(*) AS total_shipments
FROM shipments;

SELECT COUNT(*) AS total_returns
FROM returns;


-- 2. Order date range

SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM orders;


-- 3. Order status distribution

SELECT
    status,
    COUNT(*) AS total_orders
FROM orders
GROUP BY status;


-- 4. NULL checks

SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN status IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN sales_channel IS NULL THEN 1 ELSE 0 END) AS null_sales_channel,
    SUM(CASE WHEN payment_method IS NULL THEN 1 ELSE 0 END) AS null_payment_method
FROM orders;


-- 5. Duplicate primary key checks

SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


SELECT
    product_id,
    COUNT(*) AS duplicate_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;


SELECT
    order_id,
    COUNT(*) AS duplicate_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;


SELECT
    order_item_id,
    COUNT(*) AS duplicate_count
FROM order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;


SELECT
    return_id,
    COUNT(*) AS duplicate_count
FROM returns
GROUP BY return_id
HAVING COUNT(*) > 1;

-- 6. Referential integrity

SELECT
    COUNT(*) AS missing_orders
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT
    COUNT(*) AS missing_products
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- 7. Completed orders without shipment

SELECT
    COUNT(*) AS completed_orders_without_shipment
FROM orders o
LEFT JOIN shipments s
    ON o.order_id = s.order_id
WHERE o.status = 'completed'
    AND s.order_id IS NULL;


-- 8. Invalid quantity / price checks

SELECT
    COUNT(*) AS invalid_order_items
FROM order_items
WHERE quantity <= 0
    OR unit_price <= 0;


-- 9. Date logic checks

SELECT
    COUNT(*) AS invalid_delivery_dates
FROM shipments
WHERE delivery_date < shipping_date;

SELECT
    COUNT(*) AS invalid_shipping_dates
FROM shipments s
JOIN orders o
    ON s.order_id = o.order_id
WHERE s.shipping_date < o.order_date;

SELECT
    COUNT(*) AS invalid_return_dates
FROM returns r
JOIN shipments s
    ON r.order_id = s.order_id
WHERE r.return_date < s.delivery_date;
