WITH customer_years AS (
  SELECT
    `Customer ID`,
    `Customer Name`,
    Segment,
    EXTRACT(YEAR FROM DATE(`Order Date`)) AS order_year
  FROM
    `analytics-portfolio-496419.superstore.orders`
  GROUP BY
    `Customer ID`, `Customer Name`, Segment, order_year
),

yearly_cohorts AS (
  SELECT
    a.order_year,
    COUNT(DISTINCT a.`Customer ID`)                              AS total_customers,
    COUNT(DISTINCT b.`Customer ID`)                              AS retained_customers,
    COUNT(DISTINCT a.`Customer ID`) - COUNT(DISTINCT b.`Customer ID`) AS churned_customers
  FROM customer_years a
  LEFT JOIN customer_years b
    ON a.`Customer ID` = b.`Customer ID`
    AND b.order_year = a.order_year + 1
  GROUP BY a.order_year
)

SELECT
  order_year,
  total_customers,
  retained_customers,
  churned_customers,
  ROUND(retained_customers / total_customers * 100, 1) AS retention_rate_pct,
  ROUND(churned_customers / total_customers * 100, 1)  AS churn_rate_pct
FROM yearly_cohorts
ORDER BY order_year ASC;
