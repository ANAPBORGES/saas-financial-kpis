# Data Model & Power Query

## Architecture

```
Kaggle Superstore CSV
        │
        ▼
BigQuery: analytics-portfolio-496419.superstore.orders   ← raw table (1 table, ~10K rows)
        │
        ├── vw_mrr          ← monthly revenue, orders, customers, margin
        ├── vw_churn        ← yearly retention and churn rates (cohort join)
        └── vw_segments     ← revenue and profit by segment, region, YoY growth
                │
                ▼
        Power BI Desktop (DirectQuery / Import)
                │
                ├── Page: Home      ← navigation and summary
                ├── Page: MRR       ← monthly revenue trends
                ├── Page: Churn     ← retention and churn analysis
                └── Page: Segments  ← segment and region breakdown
```

---

## BigQuery Views

### vw_mrr
Built from [`01_mrr.sql`](../sql/01_mrr.sql)

| Column | Type | Description |
|---|---|---|
| `year_month` | STRING | Month in `YYYY-MM` format |
| `total_orders` | INT | Distinct orders per month |
| `active_customers` | INT | Distinct customers who ordered |
| `mrr` | FLOAT | Total revenue (SUM of Sales) |
| `total_profit` | FLOAT | Total profit |
| `profit_margin_pct` | FLOAT | Profit ÷ Revenue × 100 |

### vw_churn
Built from [`02_churn.sql`](../sql/02_churn.sql)

Uses a self-join on `customer_years` CTE: customer A in year N is matched against customer A in year N+1. If no match exists, the customer is counted as churned.

| Column | Type | Description |
|---|---|---|
| `order_year` | INT | Year (2014–2017) |
| `total_customers` | INT | Unique customers who bought in this year |
| `retained_customers` | INT | Customers who also bought in year+1 |
| `churned_customers` | INT | Customers who did NOT return in year+1 |
| `retention_rate_pct` | FLOAT | retained ÷ total × 100 |
| `churn_rate_pct` | FLOAT | churned ÷ total × 100 |

### vw_segments
Built from [`03_nrr_segments.sql`](../sql/03_nrr_segments.sql)

Uses a self-join on `segment_yearly` to calculate YoY growth per segment/region pair.

| Column | Type | Description |
|---|---|---|
| `order_year` | INT | Year |
| `Segment` | STRING | Consumer / Corporate / Home Office |
| `Region` | STRING | West / East / Central / South |
| `total_revenue` | FLOAT | Total sales revenue |
| `total_profit` | FLOAT | Total profit |
| `unique_customers` | INT | Distinct customers |
| `total_orders` | INT | Distinct orders |
| `prev_year_revenue` | FLOAT | Prior year revenue (for growth calc) |
| `yoy_growth_pct` | FLOAT | (current - prior) ÷ prior × 100 |

---

## Power Query Transformations

The three views are loaded from BigQuery via the native Power BI connector. One transformation was applied in Power Query:

### Year column (vw_mrr)

```m
#"Added Year" = Table.AddColumn(
    vw_mrr_table,
    "Year",
    each Text.Start([year_month], 4),
    type text
)
```

**Why:** The SQL view outputs `year_month` as `"2014-01"` (full month granularity). For the annual column chart on the MRR page, a standalone `Year` column was needed to group months into years without losing the monthly time series for other charts.

---

## Custom Visuals Used

| Visual | Source | Used on |
|---|---|---|
| Advance Card | AppSource | MRR, Churn, Segments (KPI cards) |
| Multi Info Cards | AppSource | Home page |
| Clustered Stacked Bar Chart | AppSource | Segments page |
| Smart Filter by SQLBI | AppSource | Navigation filters |
