-- ============================================================
-- Query 4: Advanced MRR Analysis
-- Project: SaaS Financial KPIs (Superstore)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- Is revenue growth accelerating or decelerating?
-- What is the 3-month rolling average to smooth seasonality?
-- How does cumulative YTD revenue build month over month?
--
-- Note: growth_acceleration is the change in MoM growth. Because MoM
-- growth already uses LAG, we compute it in the `with_growth` CTE first
-- and only then LAG over it — BigQuery does not allow one analytic
-- function to be nested directly inside another.

WITH monthly_revenue AS (
  SELECT
    FORMAT_DATE('%Y-%m', DATE(`Order Date`))       AS year_month,
    EXTRACT(YEAR FROM DATE(`Order Date`))           AS order_year,
    EXTRACT(MONTH FROM DATE(`Order Date`))          AS order_month,
    COUNT(DISTINCT `Order ID`)                      AS total_orders,
    COUNT(DISTINCT `Customer ID`)                   AS unique_customers,
    ROUND(SUM(Sales), 2)                            AS mrr,
    ROUND(SUM(Profit), 2)                           AS total_profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0), 4)  AS profit_margin_pct
  FROM `analytics-portfolio-496419.superstore.orders`
  GROUP BY year_month, order_year, order_month
),

with_growth AS (
  SELECT
    year_month,
    order_year,
    order_month,
    total_orders,
    unique_customers,
    mrr,
    total_profit,
    profit_margin_pct,

    -- Month-over-month growth
    LAG(mrr) OVER (ORDER BY year_month)             AS prev_month_mrr,
    ROUND(
      (mrr - LAG(mrr) OVER (ORDER BY year_month))
      / NULLIF(LAG(mrr) OVER (ORDER BY year_month), 0), 4
    )                                               AS mom_growth_pct,

    -- 3-month rolling average to smooth seasonality
    ROUND(
      AVG(mrr) OVER (ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
      2
    )                                               AS rolling_3m_avg,

    -- Cumulative YTD revenue (resets each year)
    SUM(mrr) OVER (
      PARTITION BY order_year
      ORDER BY year_month
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS ytd_revenue
  FROM monthly_revenue
)

SELECT
  with_growth.*,
  -- Growth acceleration = change in MoM growth (LAG over the already-computed column)
  ROUND(
    mom_growth_pct - LAG(mom_growth_pct) OVER (ORDER BY year_month),
    4
  )                                                 AS growth_acceleration
FROM with_growth
ORDER BY year_month ASC;
