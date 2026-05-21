# DAX Measures

This document describes all calculated measures in the Power BI model for the SaaS Financial KPIs dashboard.

---

## Core Measures

### Total Revenue
```dax
Total Revenue = SUM(vw_mrr[mrr])
```

### Total Profit
```dax
Total Profit = SUM(vw_mrr[total_profit])
```

### Profit Margin %
```dax
Profit Margin % =
DIVIDE([Total Profit], [Total Revenue], 0)
```

### Active Customers
```dax
Active Customers = SUM(vw_mrr[active_customers])
```

### Total Orders
```dax
Total Orders = SUM(vw_mrr[total_orders])
```

---

## Time Intelligence Measures

### Revenue YoY %
Compares current year revenue to the same period last year.
```dax
Revenue YoY % =
VAR CurrentRevenue = [Total Revenue]
VAR PriorRevenue =
    CALCULATE(
        [Total Revenue],
        SAMEPERIODLASTYEAR(vw_mrr[year_month])
    )
RETURN
    DIVIDE(CurrentRevenue - PriorRevenue, PriorRevenue, BLANK())
```

### Revenue MoM %
Month-over-month growth using LAG equivalent in DAX.
```dax
Revenue MoM % =
VAR CurrentRevenue = [Total Revenue]
VAR PriorRevenue =
    CALCULATE(
        [Total Revenue],
        DATEADD(vw_mrr[year_month], -1, MONTH)
    )
RETURN
    DIVIDE(CurrentRevenue - PriorRevenue, PriorRevenue, BLANK())
```

### Rolling 3M Avg Revenue
3-month rolling average to smooth seasonality and reveal the underlying trend.
```dax
Rolling 3M Avg Revenue =
AVERAGEX(
    DATESINPERIOD(
        vw_mrr[year_month],
        LASTDATE(vw_mrr[year_month]),
        -3,
        MONTH
    ),
    [Total Revenue]
)
```

### YTD Revenue
Cumulative revenue from the start of the year to the current period.
```dax
YTD Revenue =
TOTALYTD([Total Revenue], vw_mrr[year_month])
```

### YTD Revenue Prior Year
```dax
YTD Revenue Prior Year =
CALCULATE(
    [YTD Revenue],
    SAMEPERIODLASTYEAR(vw_mrr[year_month])
)
```

---

## Churn & Retention Measures

### Avg Churn (excl 2017)
Excludes 2017 because the dataset ends in December 2017 — customers from that year have no following year to "return in", artificially inflating churn to 100%.
```dax
Avg Churn (excl 2017) =
CALCULATE(
    AVERAGE(vw_churn[churn_rate_pct]),
    vw_churn[order_year] <> 2017
)
```

### Avg Retention (excl 2017)
```dax
Avg Retention (excl 2017) =
CALCULATE(
    AVERAGE(vw_churn[retention_rate_pct]),
    vw_churn[order_year] <> 2017
)
```

### Churn Trend
Compares current year churn to prior year to show if churn is improving or worsening.
```dax
Churn Trend =
VAR CurrentChurn =
    CALCULATE(AVERAGE(vw_churn[churn_rate_pct]), vw_churn[order_year] <> 2017)
VAR PriorChurn =
    CALCULATE(
        AVERAGE(vw_churn[churn_rate_pct]),
        FILTER(vw_churn, vw_churn[order_year] = MAX(vw_churn[order_year]) - 1)
    )
RETURN
    DIVIDE(CurrentChurn - PriorChurn, PriorChurn, BLANK())
```

---

## Segment & Profitability Measures

### Revenue by Segment %
Share of total revenue attributed to the selected segment.
```dax
Revenue by Segment % =
DIVIDE(
    [Total Revenue],
    CALCULATE([Total Revenue], ALL(vw_segments[Segment])),
    0
)
```

### Profit per Order
Average profit generated per order — efficiency metric.
```dax
Profit per Order =
DIVIDE([Total Profit], [Total Orders], 0)
```

### Revenue Rank (Segment)
Dynamic ranking of segments by revenue — updates with any filter applied.
```dax
Revenue Rank (Segment) =
RANKX(
    ALL(vw_segments[Segment]),
    [Total Revenue],
    ,
    DESC,
    DENSE
)
```

---

## Visual Field Mappings

### Page: MRR

| Visual | Measure / Field | Aggregation |
|---|---|---|
| KPI Card — MRR | `Total Revenue` | DAX |
| KPI Card — Active Customers | `Active Customers` | DAX |
| KPI Card — Total Orders | `Total Orders` | DAX |
| KPI Card — Profit Margin | `Profit Margin %` | DAX |
| Line chart (monthly) | `Total Revenue`, `Rolling 3M Avg Revenue` | DAX by `year_month` |
| Column chart (annual) | `Total Revenue` | DAX by `Year` |
| Line chart (customers) | `Active Customers` | SUM by `year_month` |
| Line chart (margin) | `Profit Margin %` | DAX by `year_month` |

### Page: Churn

| Visual | Measure / Field | Aggregation |
|---|---|---|
| KPI Card — Avg Churn | `Avg Churn (excl 2017)` | DAX |
| KPI Card — Avg Retention | `Avg Retention (excl 2017)` | DAX |
| KPI Card — Total Customers | `vw_churn[total_customers]` | COUNTNONNULL |
| Line chart | `vw_churn[retention_rate_pct]` | COUNTNONNULL by `order_year` |
| Donut chart | `Avg Churn`, `Avg Retention` | DAX |
| Area chart | `vw_churn[total_customers]` | SUM by `order_year` |
| Clustered Column | `retained_customers`, `churned_customers` | SUM by `order_year` |

### Page: Segments

| Visual | Measure / Field | Aggregation |
|---|---|---|
| KPI Card — Revenue | `Total Revenue` | DAX |
| KPI Card — Profit | `vw_segments[total_profit]` | SUM |
| KPI Card — Profit Margin | `Profit Margin %` | DAX |
| KPI Card — Total Orders | `Total Orders` | DAX |
| Clustered Bar | `vw_segments[total_revenue]` | SUM by `Region` |
| Clustered Column | `vw_segments[total_revenue]` | SUM by `order_year`, series `Segment` |
| Donut | `vw_segments[total_profit]` | SUM by `Segment` |
| Clustered Bar | `vw_segments[total_revenue]` | SUM by `Segment` |
