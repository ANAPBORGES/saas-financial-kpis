-- ============================================================
-- Query 6: Regional Performance Deep Dive
-- Project: SaaS Financial KPIs (Superstore)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- Which regions drive the most revenue and profit?
-- How does regional performance evolve year over year?
-- Which region has the best profit efficiency (profit per order)?

WITH regional_yearly AS (
  SELECT
    Region,
    EXTRACT(YEAR FROM DATE(`Order Date`))           AS order_year,
    COUNT(DISTINCT `Order ID`)                      AS total_orders,
    COUNT(DISTINCT `Customer ID`)                   AS unique_customers,
    ROUND(SUM(Sales), 2)                            AS total_revenue,
    ROUND(SUM(Profit), 2)                           AS total_profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0), 4)  AS profit_margin_pct,
    ROUND(AVG(Sales), 2)                            AS avg_order_value,
    ROUND(AVG(Discount), 4)                         AS avg_discount
  FROM `analytics-portfolio-496419.superstore.orders`
  GROUP BY Region, order_year
)

SELECT
  Region,
  order_year,
  total_orders,
  unique_customers,
  total_revenue,
  total_profit,
  profit_margin_pct,
  avg_order_value,
  avg_discount,

  -- Revenue rank per year
  RANK() OVER (PARTITION BY order_year ORDER BY total_revenue DESC)    AS revenue_rank,

  -- Profit rank per year
  RANK() OVER (PARTITION BY order_year ORDER BY total_profit DESC)     AS profit_rank,

  -- Revenue share within year
  ROUND(
    total_revenue / SUM(total_revenue) OVER (PARTITION BY order_year), 4
  )                                                                     AS revenue_share_pct,

  -- Profit per order (efficiency metric)
  ROUND(total_profit / NULLIF(total_orders, 0), 2)                     AS profit_per_order,

  -- YoY revenue growth per region
  LAG(total_revenue) OVER (PARTITION BY Region ORDER BY order_year)    AS prev_year_revenue,
  ROUND(
    (total_revenue - LAG(total_revenue) OVER (PARTITION BY Region ORDER BY order_year))
    / NULLIF(LAG(total_revenue) OVER (PARTITION BY Region ORDER BY order_year), 0), 4
  )                                                                     AS yoy_growth_pct,

  -- YoY profit growth per region
  LAG(total_profit) OVER (PARTITION BY Region ORDER BY order_year)     AS prev_year_profit,
  ROUND(
    (total_profit - LAG(total_profit) OVER (PARTITION BY Region ORDER BY order_year))
    / NULLIF(ABS(LAG(total_profit) OVER (PARTITION BY Region ORDER BY order_year)), 0), 4
  )                                                                     AS profit_yoy_growth_pct

FROM regional_yearly
ORDER BY order_year ASC, revenue_rank ASC;
