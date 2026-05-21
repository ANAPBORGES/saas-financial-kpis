-- ============================================================
-- Query 7: Discount Impact on Profitability
-- Project: SaaS Financial KPIs (Superstore)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- How does discounting affect profit margin?
-- Is there a discount threshold above which orders become loss-making?
-- Which segments and categories are most exposed to discounting?
--
-- Key insight: heavy discounting is one of the main causes of
-- negative profit in retail. This analysis identifies the break-even
-- discount level and flags over-discounted orders.

WITH order_level AS (
  SELECT
    `Order ID`,
    `Customer ID`,
    Segment,
    Category,
    Region,
    DATE(`Order Date`)                             AS order_date,
    ROUND(SUM(Sales), 2)                           AS order_revenue,
    ROUND(SUM(Profit), 2)                          AS order_profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0), 4) AS order_margin_pct,
    ROUND(AVG(Discount), 4)                        AS avg_discount,

    -- Classify discount level
    CASE
      WHEN AVG(Discount) = 0         THEN '0 - No discount'
      WHEN AVG(Discount) <= 0.1      THEN '1 - Low (1-10%)'
      WHEN AVG(Discount) <= 0.2      THEN '2 - Medium (11-20%)'
      WHEN AVG(Discount) <= 0.3      THEN '3 - High (21-30%)'
      ELSE                                '4 - Very high (>30%)'
    END                                            AS discount_tier

  FROM `analytics-portfolio-496419.superstore.orders`
  GROUP BY `Order ID`, `Customer ID`, Segment, Category, Region, order_date
),

discount_summary AS (
  SELECT
    discount_tier,
    Segment,
    Category,
    COUNT(DISTINCT `Order ID`)                     AS total_orders,
    COUNTIF(order_profit < 0)                      AS loss_making_orders,
    ROUND(COUNTIF(order_profit < 0) / COUNT(*), 4) AS loss_rate_pct,
    ROUND(AVG(avg_discount), 4)                    AS avg_discount,
    ROUND(AVG(order_margin_pct), 4)                AS avg_margin_pct,
    ROUND(SUM(order_revenue), 2)                   AS total_revenue,
    ROUND(SUM(order_profit), 2)                    AS total_profit
  FROM order_level
  GROUP BY discount_tier, Segment, Category
)

SELECT
  discount_tier,
  Segment,
  Category,
  total_orders,
  loss_making_orders,
  loss_rate_pct,
  avg_discount,
  avg_margin_pct,
  total_revenue,
  total_profit,

  -- Profit per order in this discount tier
  ROUND(total_profit / NULLIF(total_orders, 0), 2) AS profit_per_order,

  -- Rank discount tiers by avg margin within each segment
  RANK() OVER (
    PARTITION BY Segment
    ORDER BY avg_margin_pct DESC
  )                                                AS margin_rank_in_segment

FROM discount_summary
ORDER BY discount_tier ASC, Segment ASC, Category ASC;
