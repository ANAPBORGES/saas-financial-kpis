-- ============================================================
-- Query 5: Sub-Category Pareto Analysis
-- Project: SaaS Financial KPIs (Superstore)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- Which sub-categories drive the most revenue?
-- Does the 80/20 rule apply — do 20% of sub-categories = 80% of revenue?
-- Which sub-categories are profitable vs loss-making?

WITH subcategory_yearly AS (
  SELECT
    `Sub-Category`                                  AS sub_category,
    Category                                        AS category,
    EXTRACT(YEAR FROM DATE(`Order Date`))           AS order_year,
    COUNT(DISTINCT `Order ID`)                      AS total_orders,
    ROUND(SUM(Sales), 2)                            AS total_revenue,
    ROUND(SUM(Profit), 2)                           AS total_profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0), 4)  AS profit_margin_pct,
    ROUND(AVG(Discount), 4)                         AS avg_discount
  FROM `analytics-portfolio-496419.superstore.orders`
  GROUP BY sub_category, category, order_year
),

with_window_metrics AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY order_year ORDER BY total_revenue DESC)  AS revenue_rank,

    ROUND(
      total_revenue / SUM(total_revenue) OVER (PARTITION BY order_year), 4
    )                                                                   AS revenue_share_pct,

    -- Cumulative revenue share — enables Pareto identification
    ROUND(
      SUM(total_revenue) OVER (
        PARTITION BY order_year
        ORDER BY total_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) / SUM(total_revenue) OVER (PARTITION BY order_year), 4
    )                                                                   AS cumulative_revenue_share_pct,

    -- YoY growth per sub-category
    LAG(total_revenue) OVER (PARTITION BY sub_category ORDER BY order_year) AS prev_year_revenue
  FROM subcategory_yearly
)

SELECT
  sub_category,
  category,
  order_year,
  total_orders,
  total_revenue,
  total_profit,
  profit_margin_pct,
  avg_discount,
  revenue_rank,
  revenue_share_pct,
  cumulative_revenue_share_pct,

  CASE
    WHEN cumulative_revenue_share_pct <= 0.8 THEN 'Top 80%'
    ELSE 'Long tail'
  END                                                                   AS pareto_group,

  -- Flag loss-making sub-categories
  CASE WHEN total_profit < 0 THEN 'Loss-making' ELSE 'Profitable' END  AS profitability,

  prev_year_revenue,
  CASE
    WHEN prev_year_revenue IS NULL THEN NULL
    ELSE ROUND((total_revenue - prev_year_revenue) / NULLIF(prev_year_revenue, 0), 4)
  END                                                                   AS yoy_growth_pct

FROM with_window_metrics
ORDER BY order_year ASC, revenue_rank ASC;
