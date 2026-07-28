# Data Model

How the single CSV becomes a star schema, and why each decision was made.

Shaping lives in [`power_query.md`](./power_query.md); aggregation lives in
[`measures.md`](./measures.md). This file is the contract between them.

---

## Architecture

```
data/superstore.csv   (versioned in this repo — the single source of truth)
        │
        └──► Power Query (M)
               p_DataPath ──► src_superstore  (staging · load disabled · buffered)
                                   │
                    ┌──────────────┼──────────────┬──────────────┐
                    ▼              ▼              ▼              ▼
               dim_date      dim_customer   dim_product   dim_geography
                    │              │              │              │
                    └──────────────┴──────┬───────┴──────────────┘
                                          ▼
                                     fact_orders
                                          │
                                          ▼
                            DAX measures  ──►  report pages
```

The report reads the CSV directly, so it needs no cloud account. The BigQuery path
(`/sql`) is optional and only prototypes the same metric logic.

---

## Star schema

`fact_orders` is the only table containing measures. Everything descriptive sits in
a dimension, joined one-to-many, filtering in a single direction.

| Table | Grain | Rows | Role |
|---|---|---|---|
| `fact_orders` | one order line | 9,994 | measures + foreign keys |
| `dim_date` | one calendar day | 1,461 | time intelligence |
| `dim_customer` | one customer | 793 | segment, value tier, lifetime aggregates |
| `dim_product` | one product | 1,862 | category, sub-category, static rank |
| `dim_geography` | one state + city | 604 | region, state, city for maps |
| `Discount Reduction` | parameter value | 11 | what-if scenario (disconnected) |

### Relationships

| From | To | Cardinality | Direction | Active |
|---|---|---|---|---|
| `fact_orders[order_date]` | `dim_date[Date]` | many-to-one | single | ✅ |
| `fact_orders[customer_id]` | `dim_customer[customer_id]` | many-to-one | single | ✅ |
| `fact_orders[product_id]` | `dim_product[product_id]` | many-to-one | single | ✅ |
| `fact_orders[geo_key]` | `dim_geography[geo_key]` | many-to-one | single | ✅ |
| `fact_orders[ship_date]` | `dim_date[Date]` | many-to-one | single | ❌ inactive |
| `Discount Reduction` | — | — | — | disconnected |

**Three deliberate modeling choices:**

1. **Single-direction filtering only.** Bidirectional cross-filtering is left off —
   it creates ambiguous filter paths once more than one dimension is in play, and
   nothing in this report needs a dimension filtered by the fact table.

2. **`ship_date` is a second, inactive relationship** to the same `dim_date`. A
   model cannot have two active relationships between the same pair of tables. It
   stays inactive and is activated per-measure with `USERELATIONSHIP` when a
   shipping-date view is needed — order date is the default for every other measure.

3. **`Discount Reduction` is disconnected on purpose.** A what-if parameter must
   not filter the fact table; it is read as a scalar with `SELECTEDVALUE` inside
   `SUMX`. Joining it would silently filter out every row that does not match.

---

## Column reference

Only the columns the measures actually consume. Full derivation in
[`power_query.md`](./power_query.md).

### `fact_orders`

| Column | Type | Notes |
|---|---|---|
| `order_id` | text | `DISTINCTCOUNT` target for `[Total Orders]` — 5,009 distinct across 9,994 lines |
| `order_date` | date | active relationship to `dim_date` |
| `ship_date` | date | inactive relationship |
| `customer_id`, `product_id`, `geo_key` | text | foreign keys |
| `sales`, `profit`, `quantity`, `discount` | decimal | the additive measures |
| `days_to_ship` | integer | `ship_date − order_date`, precomputed |
| `is_profitable` | boolean | `profit > 0` — filters `[Loss-Making Orders]` |
| `margin_pct` | decimal | line-level `profit / sales` — used by `SUMX` in the what-if |
| `discount_tier` | text | No Discount · 1-10% · 11-20% · 21-30% · Over 30% |
| `discount_tier_sort` | integer | sort-by column for the above |

> **Why `is_profitable` and `margin_pct` are Power Query columns, not DAX
> calculated columns:** both are row-level and never change with filter context.
> Computed once at refresh they compress into the column store; as DAX calculated
> columns they would be recomputed on every model refresh with no benefit, and
> `margin_pct` in particular is iterated row-by-row by `SUMX` in Group 5–6 —
> having it materialised keeps that iteration cheap.

### `dim_customer`

| Column | Type | Notes |
|---|---|---|
| `customer_id` | text | key |
| `segment` | text | Consumer / Corporate / Home Office |
| `customer_value_tier` | text | High / Mid / Low — percentile-based, not hard-coded |
| `customer_value_tier_sort` | integer | sort-by column |
| `first_order_date` | date | drives `[New Customers]` |
| `last_order_date` | date | — |
| `lifetime_revenue`, `lifetime_profit` | decimal | precomputed aggregates |
| `order_count`, `tenure_days` | integer | — |

### `dim_product`

| Column | Type | Notes |
|---|---|---|
| `product_id` | text | key |
| `product_name`, `category`, `sub_category` | text | — |
| `revenue_rank` | integer | **static** rank over the whole dataset |
| `is_profitable_product` | boolean | — |
| `product_margin_pct` | decimal | — |

> `revenue_rank` (static attribute, usable in a slicer) and `[Product Revenue Rank]`
> (a `RANKX` measure that recalculates under the user's filters) coexist by design —
> they answer different questions.

### `dim_date`

| Column | Type | Notes |
|---|---|---|
| `Date` | date | key · **Mark as date table** |
| `Year`, `Month Number`, `Quarter Number` | integer | — |
| `Month`, `Quarter`, `Year Month`, `Day of Week` | text | sorted by their numeric twins |
| `Year Month Sort` | integer | `YYYY * 100 + MM` |
| `Is Weekend` | boolean | — |

---

## Required model settings

Missing any of these produces wrong output rather than an error, so they are worth
checking explicitly:

| Setting | Where | Why |
|---|---|---|
| Mark `dim_date` as date table | Table tools ▸ Mark as date table | `DATESYTD` / `SAMEPERIODLASTYEAR` need it |
| `Month` sort by `Month Number` | Column tools ▸ Sort by column | otherwise Apr, Aug, Dec… |
| `Year Month` sort by `Year Month Sort` | same | otherwise 2015-01, 2015-02 … sorts as text |
| `discount_tier` sort by `discount_tier_sort` | same | otherwise "1-10%" follows "No Discount" |
| `customer_value_tier` sort by `customer_value_tier_sort` | same | otherwise High, Low, Mid |
| Auto Date/Time **off** | File ▸ Options ▸ Data Load | prevents hidden per-column calendars |
| `Discount Reduction` formatted as % | Column tools ▸ Format | slicer reads "15%" not "0.15" |

---

## Validation

Verified directly against `data/superstore.csv`:

| Check | Expected |
|---|---|
| `fact_orders` rows | 9,994 |
| Distinct orders | 5,009 |
| Distinct customers | 793 |
| Date range | 2015-01-01 → 2018-12-31 |
| `[Total Revenue]` | 2,297,200.86 |
| `[Total Profit]` | 286,397.02 |
| `[Profit Margin %]` | 12.47% |

Same figures the SQL in [`/sql`](../sql) returns — the two paths are meant to agree.

---

## Metric definitions from SQL

The `/sql` queries prototype the metrics before they become DAX. Their output
columns double as the semantic dictionary.

### MRR — [`01_mrr.sql`](../sql/01_mrr.sql)

| Column | Description |
|---|---|
| `year_month` | Month in `YYYY-MM` |
| `total_orders` | Distinct orders per month |
| `active_customers` | Distinct customers who ordered |
| `mrr` | Total revenue |
| `profit_margin_pct` | Profit ÷ Revenue × 100 |

### Churn — [`02_churn.sql`](../sql/02_churn.sql)

Self-join on a `customer_years` CTE: a customer active in year *N* is matched to
year *N+1*; no match ⇒ churned.

| Column | Description |
|---|---|
| `order_year` | Year (2015–2018) |
| `retained_customers` | Also bought in year+1 |
| `churned_customers` | Did not return in year+1 |
| `retention_rate_pct` / `churn_rate_pct` | retained or churned ÷ total × 100 |

> **Boundary year:** 2018 is the last year in the data, so it has no *year+1* to be
> retained into and reads 100% churn by construction — exclude it when reading the trend.

### Segments — [`03_nrr_segments.sql`](../sql/03_nrr_segments.sql)

Self-join on `segment_yearly` for YoY growth per segment/region pair.

| Column | Description |
|---|---|
| `order_year`, `Segment`, `Region` | grain |
| `total_revenue`, `total_profit` | additive measures |
| `yoy_growth_pct` | (current − prior) ÷ prior × 100 |
