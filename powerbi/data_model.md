# Data Model & Power Query

## Architecture

```
data/superstore.csv   (versioned in this repo — the single source of truth)
        │
        ├──────────────► Power BI Desktop
        │                   Power Query (M): Get Data ▸ Text/CSV, typed columns, Year column
        │                   Data model + DAX measures
        │                   ├── Page: Home      ← navigation and summary
        │                   ├── Page: MRR       ← monthly revenue trends
        │                   ├── Page: Churn     ← retention and churn analysis
        │                   └── Page: Segments  ← segment and region breakdown
        │
        └──────────────► BigQuery table `superstore.orders`  (optional)
                            SQL prototypes of the same metrics (see /sql)
```

The dashboard reads the CSV directly, so it needs no cloud account. The BigQuery path is
optional and only used to run the SQL prototypes.

---

## SQL metric prototypes

The three analytical shapes below (built in `/sql`) define the metrics that the Power BI
model reproduces with DAX. Column descriptions double as the semantic dictionary.

### MRR — from [`01_mrr.sql`](../sql/01_mrr.sql)

| Column | Type | Description |
|---|---|---|
| `year_month` | STRING | Month in `YYYY-MM` format |
| `total_orders` | INT | Distinct orders per month |
| `active_customers` | INT | Distinct customers who ordered |
| `mrr` | FLOAT | Total revenue (SUM of Sales) |
| `total_profit` | FLOAT | Total profit |
| `profit_margin_pct` | FLOAT | Profit ÷ Revenue × 100 |

### Churn — from [`02_churn.sql`](../sql/02_churn.sql)

Self-join on a `customer_years` CTE: a customer active in year *N* is matched to year *N+1*; no match ⇒ churned.

| Column | Type | Description |
|---|---|---|
| `order_year` | INT | Year (2015–2018) |
| `total_customers` | INT | Unique customers who bought in this year |
| `retained_customers` | INT | Customers who also bought in year+1 |
| `churned_customers` | INT | Customers who did NOT return in year+1 |
| `retention_rate_pct` | FLOAT | retained ÷ total × 100 |
| `churn_rate_pct` | FLOAT | churned ÷ total × 100 |

> **Boundary year:** 2018 is the last year in the data, so it has no *year+1* to be retained into and reads 100% churn by construction — exclude it when interpreting the trend.

### Segments — from [`03_nrr_segments.sql`](../sql/03_nrr_segments.sql)

Self-join on `segment_yearly` for YoY growth per segment/region pair.

| Column | Type | Description |
|---|---|---|
| `order_year` | INT | Year |
| `Segment` | STRING | Consumer / Corporate / Home Office |
| `Region` | STRING | West / East / Central / South |
| `total_revenue` | FLOAT | Total sales revenue |
| `total_profit` | FLOAT | Total profit |
| `unique_customers` | INT | Distinct customers |
| `total_orders` | INT | Distinct orders |
| `yoy_growth_pct` | FLOAT | (current − prior) ÷ prior × 100 |

---

## Power Query Transformations

The CSV is loaded via **Get Data ▸ Text/CSV**. Columns are typed (dates, decimals), and a
standalone **Year** column is derived from the order date for annual roll-ups:

```m
#"Added Year" = Table.AddColumn(
    Source,
    "Year",
    each Date.Year([Order Date]),
    Int64.Type
)
```

**Why:** the monthly time series is kept intact for trend charts, while a discrete `Year`
column drives the annual column/comparison visuals without a separate query.

---

## Custom Visuals Used

| Visual | Source | Used on |
|---|---|---|
| Advance Card | AppSource | MRR, Churn, Segments (KPI cards) |
| Multi Info Cards | AppSource | Home page |
| Clustered Stacked Bar Chart | AppSource | Segments page |
| Smart Filter by SQLBI | AppSource | Navigation filters |
