-- ============================================
-- Query 1: Monthly Recurring Revenue (MRR)
-- Project: SaaS Financial KPIs (Superstore)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================
SELECT
  FORMAT_DATE('%Y-%m', DATE(`Order Date`))   AS year_month,
  COUNT(DISTINCT `Order ID`)                  AS total_orders,
  COUNT(DISTINCT `Customer ID`)               AS active_customers,
  ROUND(SUM(Sales), 2)                        AS mrr,
  ROUND(SUM(Profit), 2)                       AS total_profit,
  ROUND(SUM(Profit) / SUM(Sales) * 100, 1)   AS profit_margin_pct
FROM `analytics-portfolio-496419.superstore.orders`
GROUP BY year_month
ORDER BY year_month ASC;
