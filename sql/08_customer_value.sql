-- ============================================================
-- Query 8: Customer Value Analysis
-- Project: SaaS Financial KPIs (Superstore)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- Who are the most valuable customers?
-- Which customers are high-revenue but low-profit (risky)?
-- How does customer value distribute across segments and regions?

WITH customer_metrics AS (
  SELECT
    `Customer ID`,
    `Customer Name`,
    Segment,
    Region,
    COUNT(DISTINCT `Order ID`)                      AS total_orders,
    ROUND(SUM(Sales), 2)                            AS total_revenue,
    ROUND(SUM(Profit), 2)                           AS total_profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0), 4)  AS profit_margin_pct,
    ROUND(AVG(Sales), 2)                            AS avg_order_value,
    ROUND(AVG(Discount), 4)                         AS avg_discount,
    MIN(DATE(`Order Date`))                         AS first_order_date,
    MAX(DATE(`Order Date`))                         AS last_order_date,
    DATE_DIFF(MAX(DATE(`Order Date`)), MIN(DATE(`Order Date`)), DAY) AS customer_lifespan_days
  FROM `analytics-portfolio-496419.superstore.orders`
  GROUP BY `Customer ID`, `Customer Name`, Segment, Region
),

with_rankings AS (
  SELECT
    *,
    -- Revenue rank overall
    RANK() OVER (ORDER BY total_revenue DESC)            AS revenue_rank,

    -- Revenue rank within segment
    RANK() OVER (PARTITION BY Segment ORDER BY total_revenue DESC) AS revenue_rank_in_segment,

    -- Revenue percentile (top 10%, top 25%, etc.)
    NTILE(10) OVER (ORDER BY total_revenue DESC)         AS revenue_decile,

    -- Profit rank overall
    RANK() OVER (ORDER BY total_profit DESC)             AS profit_rank,

    -- Classify customer value vs profitability
    CASE
      WHEN total_revenue >= PERCENTILE_CONT(total_revenue, 0.75) OVER ()
        AND total_profit >= PERCENTILE_CONT(total_profit, 0.75) OVER ()
        THEN 'High Value + Profitable'
      WHEN total_revenue >= PERCENTILE_CONT(total_revenue, 0.75) OVER ()
        AND total_profit < 0
        THEN 'High Revenue + Loss-making'
      WHEN total_revenue < PERCENTILE_CONT(total_revenue, 0.25) OVER ()
        THEN 'Low Value'
      ELSE 'Mid Value'
    END                                                  AS customer_tier
  FROM customer_metrics
)

SELECT
  `Customer ID`,
  `Customer Name`,
  Segment,
  Region,
  total_orders,
  total_revenue,
  total_profit,
  profit_margin_pct,
  avg_order_value,
  avg_discount,
  first_order_date,
  last_order_date,
  customer_lifespan_days,
  revenue_rank,
  revenue_rank_in_segment,
  revenue_decile,
  profit_rank,
  customer_tier
FROM with_rankings
ORDER BY revenue_rank ASC;
