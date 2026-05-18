WITH segment_yearly AS (
  SELECT
    Segment,
    Region,
    EXTRACT(YEAR FROM DATE(`Order Date`))   AS order_year,
    ROUND(SUM(Sales), 2)                    AS total_revenue,
    ROUND(SUM(Profit), 2)                   AS total_profit,
    COUNT(DISTINCT `Customer ID`)           AS unique_customers,
    COUNT(DISTINCT `Order ID`)              AS total_orders
  FROM
    `analytics-portfolio-496419.superstore.orders`
  GROUP BY
    Segment, Region, order_year
),

with_growth AS (
  SELECT
    a.Segment,
    a.Region,
    a.order_year,
    a.total_revenue,
    a.total_profit,
    a.unique_customers,
    a.total_orders,
    b.total_revenue AS prev_year_revenue,
    ROUND((a.total_revenue - b.total_revenue)
      / NULLIF(b.total_revenue, 0) * 100, 1) AS yoy_growth_pct
  FROM segment_yearly a
  LEFT JOIN segment_yearly b
    ON a.Segment = b.Segment
    AND a.Region = b.Region
    AND a.order_year = b.order_year + 1
)

SELECT
  order_year,
  Segment,
  Region,
  total_revenue,
  total_profit,
  unique_customers,
  total_orders,
  prev_year_revenue,
  yoy_growth_pct
FROM with_growth
ORDER BY order_year ASC, total_revenue DESC;
