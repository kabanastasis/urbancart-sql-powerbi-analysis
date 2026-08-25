-- UrbanCart - Business Performance Analysis

-- This analysis investigates revenue growth, profitability,
-- customer behavior, discounts, returns, refunds and shipping
-- performance.
--
-- Unless stated otherwise, financial analysis includes only
-- completed orders.


-- 1. Monthly Revenue & Completed Orders

SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    ROUND(SUM(oi.unit_price * oi.quantity), 2) AS monthly_revenue,
    COUNT(DISTINCT o.order_id) AS completed_orders
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.status = 'completed'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;


-- 2. Month-over-Month Revenue Growth

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        SUM(oi.unit_price * oi.quantity) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
),

revenue_lag AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue
    FROM monthly_revenue
)

SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(
        (revenue - previous_month_revenue)
        / previous_month_revenue * 100,
        2
    ) AS revenue_growth_pct
FROM revenue_lag
ORDER BY month;


-- 3. Average Order Value

SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    ROUND(SUM(oi.unit_price * oi.quantity), 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    ROUND(
        SUM(oi.unit_price * oi.quantity)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.status = 'completed'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;


-- 4. Cancellation Rate

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    COUNT(*) AS total_orders,
    SUM(CASE
        WHEN status = 'cancelled' THEN 1
        ELSE 0
    END) AS cancelled_orders,
    ROUND(
        SUM(CASE
            WHEN status = 'cancelled' THEN 1
            ELSE 0
        END) / COUNT(*) * 100,
        2
    ) AS cancellation_rate
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;


-- 5. Monthly Active Customers

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    COUNT(DISTINCT customer_id) AS active_customers
FROM orders
WHERE status = 'completed'
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;


-- 6. New vs Returning Customers

WITH first_order AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
),

monthly_customers AS (
    SELECT DISTINCT
        o.customer_id,
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        DATE_FORMAT(f.first_order_date, '%Y-%m') AS first_order_month
    FROM orders o
    JOIN first_order f
        ON o.customer_id = f.customer_id
    WHERE o.status = 'completed'
)

SELECT
    month,
    COUNT(DISTINCT CASE
        WHEN month = first_order_month
        THEN customer_id
    END) AS new_customers,

    COUNT(DISTINCT CASE
        WHEN month > first_order_month
        THEN customer_id
    END) AS returning_customers

FROM monthly_customers
GROUP BY month
ORDER BY month;


-- 7. Revenue: New vs Returning Customers

WITH first_order AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
),

customer_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,

        CASE
            WHEN DATE_FORMAT(o.order_date, '%Y-%m')
                 = DATE_FORMAT(f.first_order_date, '%Y-%m')
            THEN 'New Customer'
            ELSE 'Returning Customer'
        END AS customer_type,

        SUM(oi.unit_price * oi.quantity) AS revenue

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN first_order f
        ON o.customer_id = f.customer_id

    WHERE o.status = 'completed'

    GROUP BY
        DATE_FORMAT(o.order_date, '%Y-%m'),
        customer_type
)

SELECT
    month,
    customer_type,
    ROUND(revenue, 2) AS revenue
FROM customer_revenue
ORDER BY month, customer_type;


-- 8. Category Performance

SELECT
    p.category,

    ROUND(
        SUM(oi.unit_price * oi.quantity),
        2
    ) AS revenue,

    SUM(oi.quantity) AS units_sold,

    COUNT(DISTINCT o.order_id) AS total_orders,

    ROUND(
        SUM(oi.unit_price * oi.quantity)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value,

    ROUND(
        SUM(oi.quantity * p.unit_cost),
        2
    ) AS cost_of_goods_sold,

    ROUND(
        SUM(
            (oi.unit_price - p.unit_cost)
            * oi.quantity
        ),
        2
    ) AS gross_profit,

    ROUND(
        SUM(
            (oi.unit_price - p.unit_cost)
            * oi.quantity
        )
        / SUM(oi.unit_price * oi.quantity)
        * 100,
        2
    ) AS gross_margin_pct

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id

WHERE o.status = 'completed'

GROUP BY p.category
ORDER BY revenue DESC;


-- 9. Sales Channel Performance

WITH channel_metrics AS (
    SELECT
        o.sales_channel,

        COUNT(DISTINCT o.order_id) AS total_orders,

        SUM(
            oi.unit_price * oi.quantity
        ) AS revenue,

        SUM(
            oi.quantity * p.unit_cost
        ) AS cogs

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.status = 'completed'

    GROUP BY o.sales_channel
)

SELECT
    sales_channel,
    total_orders,

    ROUND(
        total_orders
        / SUM(total_orders) OVER ()
        * 100,
        2
    ) AS order_share_pct,

    ROUND(revenue, 2) AS revenue,

    ROUND(
        revenue
        / SUM(revenue) OVER ()
        * 100,
        2
    ) AS revenue_share_pct,

    ROUND(
        (revenue - cogs)
        / revenue
        * 100,
        2
    ) AS gross_margin_pct

FROM channel_metrics
ORDER BY revenue DESC;


-- 10. Discount Analysis

SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,

    ROUND(
        SUM(
            (p.list_price - oi.unit_price)
            * oi.quantity
        ),
        2
    ) AS discount_amount,

    ROUND(
        SUM(
            p.list_price * oi.quantity
        ),
        2
    ) AS list_value,

    ROUND(
        SUM(
            (p.list_price - oi.unit_price)
            * oi.quantity
        )
        /
        SUM(
            p.list_price * oi.quantity
        )
        * 100,
        2
    ) AS weighted_discount_pct

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id

WHERE o.status = 'completed'

GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;


-- 11. Return Rate

SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,

    COUNT(DISTINCT o.order_id) AS completed_orders,

    COUNT(DISTINCT r.order_id) AS returned_orders,

    ROUND(
        COUNT(DISTINCT r.order_id)
        / COUNT(DISTINCT o.order_id)
        * 100,
        2
    ) AS return_rate

FROM orders o
LEFT JOIN returns r
    ON o.order_id = r.order_id

WHERE o.status = 'completed'

GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;


-- 12. Refund Rate

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        SUM(
            oi.unit_price * oi.quantity
        ) AS revenue

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.status = 'completed'

    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
),

monthly_refunds AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        COALESCE(
            SUM(r.refund_amount),
            0
        ) AS refund_amount

    FROM orders o
    LEFT JOIN returns r
        ON o.order_id = r.order_id

    WHERE o.status = 'completed'

    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)

SELECT
    mr.month,

    ROUND(
        mr.revenue,
        2
    ) AS revenue,

    ROUND(
        mf.refund_amount,
        2
    ) AS refund_amount,

    ROUND(
        mf.refund_amount
        / mr.revenue
        * 100,
        2
    ) AS refund_rate

FROM monthly_revenue mr
JOIN monthly_refunds mf
    ON mr.month = mf.month

ORDER BY mr.month;


-- 13. Shipping Cost Analysis

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,

        SUM(
            oi.unit_price * oi.quantity
        ) AS revenue,

        COUNT(
            DISTINCT o.order_id
        ) AS completed_orders

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.status = 'completed'

    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
),

monthly_shipping AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,

        SUM(
            s.shipping_cost
        ) AS shipping_cost

    FROM orders o
    JOIN shipments s
        ON o.order_id = s.order_id

    WHERE o.status = 'completed'

    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)

SELECT
    mr.month,

    ROUND(
        mr.revenue,
        2
    ) AS revenue,

    ROUND(
        ms.shipping_cost,
        2
    ) AS shipping_cost,

    ROUND(
        ms.shipping_cost
        / mr.revenue
        * 100,
        2
    ) AS shipping_cost_rate,

    ROUND(
        ms.shipping_cost
        / mr.completed_orders,
        2
    ) AS average_shipping_cost_per_order

FROM monthly_revenue mr
JOIN monthly_shipping ms
    ON mr.month = ms.month

ORDER BY mr.month;


-- 14. Adjusted Profitability

WITH sales AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,

        SUM(
            oi.unit_price * oi.quantity
        ) AS revenue,

        SUM(
            oi.quantity * p.unit_cost
        ) AS cogs

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.status = 'completed'

    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
),

refunds AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,

        COALESCE(
            SUM(r.refund_amount),
            0
        ) AS refund_amount

    FROM orders o
    LEFT JOIN returns r
        ON o.order_id = r.order_id

    WHERE o.status = 'completed'

    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
),

shipping AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,

        SUM(
            s.shipping_cost
        ) AS shipping_cost

    FROM orders o
    JOIN shipments s
        ON o.order_id = s.order_id

    WHERE o.status = 'completed'

    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)

SELECT
    s.month,

    ROUND(
        s.revenue,
        2
    ) AS revenue,

    ROUND(
        s.cogs,
        2
    ) AS cogs,

    ROUND(
        r.refund_amount,
        2
    ) AS refund_amount,

    ROUND(
        sh.shipping_cost,
        2
    ) AS shipping_cost,

    ROUND(
        s.revenue
        - s.cogs
        - r.refund_amount
        - sh.shipping_cost,
        2
    ) AS contribution_profit

FROM sales s
JOIN refunds r
    ON s.month = r.month
JOIN shipping sh
    ON s.month = sh.month

ORDER BY s.month;
