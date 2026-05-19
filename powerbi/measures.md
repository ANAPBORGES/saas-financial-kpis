# DAX Measures

This document describes the calculated measures created in Power BI for the SaaS Financial KPIs dashboard.

The data model connects directly to three BigQuery views (`vw_mrr`, `vw_churn`, `vw_segments`). Most KPI cards use implicit aggregations (`SUM`, `AVERAGE`, `COUNTROWS`) on the view columns. Two explicit DAX measures were created to handle a specific analytical constraint in the churn calculation.

---

## Churn & Retention Measures

### Avg Churn (excl 2017)

```dax
Avg Churn (excl 2017) =
CALCULATE(
    AVERAGE(vw_churn[churn_rate_pct]),
    vw_churn[order_year] <> 2017
)
```

**Why exclude 2017?**
The churn calculation requires knowing whether a customer who bought in year N returned in year N+1. Since the dataset ends in December 2017, there is no 2018 data — every customer from 2017 would appear as "churned" simply because the observation window closes. Including 2017 would artificially inflate the churn rate by 100% for that cohort. Excluding it ensures the metric reflects real behavioral churn rather than a data boundary artifact.

---

### Avg Retention (excl 2017)

```dax
Avg Retention (excl 2017) =
CALCULATE(
    AVERAGE(vw_churn[retention_rate_pct]),
    vw_churn[order_year] <> 2017
)
```

Same rationale as above — retention is the complement of churn (retention + churn = 100%), so the same exclusion applies.

---

## Implicit Aggregations by Page

These are not explicit measures but direct column aggregations used in each visual.

### MRR Page

| Visual | Field | Aggregation |
|---|---|---|
| KPI Card | `vw_mrr.mrr` | SUM |
| KPI Card | `vw_mrr.active_customers` | SUM |
| KPI Card | `vw_mrr.total_orders` | SUM |
| KPI Card | `vw_mrr.profit_margin_pct` | SUM |
| Line chart (trend) | `vw_mrr.mrr` | SUM by `year_month` |
| Line chart (dual axis) | `vw_mrr.mrr`, `vw_mrr.total_profit` | SUM by `year_month` |
| Line chart | `vw_mrr.active_customers` | SUM by `year_month` |
| Line chart | `vw_mrr.profit_margin_pct` | SUM by `year_month` |
| Column chart | `vw_mrr.mrr` | SUM by `Year` |

### Churn Page

| Visual | Field | Aggregation |
|---|---|---|
| KPI Card | `Avg Churn (excl 2017)` | DAX measure |
| KPI Card | `Avg Retention (excl 2017)` | DAX measure |
| KPI Card | `vw_churn.total_customers` | COUNTNONNULL |
| Line chart | `vw_churn.retention_rate_pct` | COUNTNONNULL by `order_year` |
| Donut chart | `Avg Churn`, `Avg Retention` | DAX measures |
| Area chart | `vw_churn.total_customers` | SUM by `order_year` |
| Clustered Column | `vw_churn.retained_customers`, `vw_churn.churned_customers` | SUM by `order_year` |

### Segments Page

| Visual | Field | Aggregation |
|---|---|---|
| KPI Card | `vw_segments.total_revenue` | SUM |
| KPI Card | `vw_segments.total_profit` | SUM |
| KPI Card | `vw_mrr.profit_margin_pct` | SUM |
| KPI Card | `vw_mrr.total_orders` | SUM |
| Clustered Bar | `vw_segments.total_revenue` | SUM by `Region` |
| Clustered Column | `vw_segments.total_revenue` | SUM by `order_year`, series `Segment` |
| Donut chart | `vw_segments.total_profit` | SUM by `Segment` |
| Clustered Bar | `vw_segments.total_revenue` | SUM by `Segment` |
