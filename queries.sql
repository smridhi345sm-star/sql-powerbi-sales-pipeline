-- ============================================================
-- SQL + Power BI End-to-End Pipeline
-- Query Set: 5 analyst-grade queries demonstrating JOINs,
-- CTEs, and window functions
-- ============================================================


-- ------------------------------------------------------------
-- QUERY 1: Monthly Revenue Trend with Running Total
-- Skills: JOIN, aggregation, window function (SUM OVER)
-- Business question: How is revenue trending month over month,
-- and what is the cumulative revenue for the fiscal period?
-- ------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_date) AS order_month,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    ROUND(SUM(revenue) OVER (ORDER BY order_month), 2) AS running_total_revenue
FROM monthly_revenue
ORDER BY order_month;


-- ------------------------------------------------------------
-- QUERY 2: Top 3 Products per Category by Revenue
-- Skills: JOIN across 3 tables, CTE, window function (RANK)
-- Business question: Which products are the top revenue
-- drivers within each category?
-- ------------------------------------------------------------
WITH product_revenue AS (
    SELECT
        p.category,
        p.product_name,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.category, p.product_name
),
ranked AS (
    SELECT
        category,
        product_name,
        revenue,
        RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS category_rank
    FROM product_revenue
)
SELECT category, product_name, revenue, category_rank
FROM ranked
WHERE category_rank <= 3
ORDER BY category, category_rank;


-- ------------------------------------------------------------
-- QUERY 3: Customer Segmentation (RFM-style)
-- Skills: CTE chaining, JOIN, CASE, date functions
-- Business question: Which customers are high-value / at-risk
-- based on recency, frequency, and monetary value?
-- ------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.region,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS monetary,
        MAX(o.order_date) AS last_order_date
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.customer_name, c.region
),
scored AS (
    SELECT
        *,
        CAST(julianday('2025-06-30') - julianday(last_order_date) AS INTEGER) AS recency_days
    FROM customer_orders
)
SELECT
    customer_id,
    customer_name,
    region,
    frequency,
    monetary,
    recency_days,
    CASE
        WHEN recency_days <= 60 AND monetary >= 20000 THEN 'High-Value Active'
        WHEN recency_days > 180 THEN 'At Risk'
        WHEN frequency >= 6 THEN 'Loyal'
        ELSE 'Regular'
    END AS segment
FROM scored
ORDER BY monetary DESC;


-- ------------------------------------------------------------
-- QUERY 4: Month-over-Month Growth Rate by Region
-- Skills: CTE, window function (LAG), JOIN, NULL-safe division
-- Business question: Which regions are growing or declining,
-- and by how much month over month?
-- ------------------------------------------------------------
WITH regional_monthly AS (
    SELECT
        o.region,
        strftime('%Y-%m', o.order_date) AS order_month,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.region, order_month
)
SELECT
    region,
    order_month,
    revenue,
    LAG(revenue) OVER (PARTITION BY region ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (PARTITION BY region ORDER BY order_month))
        / NULLIF(LAG(revenue) OVER (PARTITION BY region ORDER BY order_month), 0),
        2
    ) AS mom_growth_pct
FROM regional_monthly
ORDER BY region, order_month;


-- ------------------------------------------------------------
-- QUERY 5: Average Order Value (AOV) and Margin % by Region
-- Skills: multi-table JOIN, aggregation, derived margin metric
-- Business question: Which regions have the healthiest margins
-- and order economics, not just top-line revenue?
-- ------------------------------------------------------------
SELECT
    o.region,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS total_revenue,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) * 1.0
          / COUNT(DISTINCT o.order_id), 2) AS avg_order_value,
    ROUND(SUM(oi.quantity * (oi.unit_price * (1 - oi.discount_pct) - p.unit_cost)), 2) AS total_profit,
    ROUND(
        100.0 * SUM(oi.quantity * (oi.unit_price * (1 - oi.discount_pct) - p.unit_cost))
        / NULLIF(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 0),
        2
    ) AS margin_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY o.region
ORDER BY total_revenue DESC;
