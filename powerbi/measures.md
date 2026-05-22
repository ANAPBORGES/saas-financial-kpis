# DAX Measures

Complete documentation of all DAX measures in the Power BI model.
Organized in 6 groups by analytical purpose.

---

## Data Model

Star schema with 4 tables:
- `fact_orders` — one row per order line (from BigQuery)
- `dim_customer` — one row per customer with value tier classification
- `dim_product` — one row per product with revenue rank and profitability flag
- `dim_date` — full date dimension generated in Power Query M (2014–2017)

---

## Group 1 — Core Measures

```dax
Total Revenue = SUM(fact_orders[sales])

Total Profit = SUM(fact_orders[profit])

Profit Margin % = DIVIDE([Total Profit], [Total Revenue], 0)

Total Orders = DISTINCTCOUNT(fact_orders[order_id])

Total Customers = DISTINCTCOUNT(fact_orders[customer_id])

Avg Order Value = DIVIDE([Total Revenue], [Total Orders], 0)

Total Quantity = SUM(fact_orders[quantity])

Avg Discount = AVERAGE(fact_orders[discount])
```

---

## Group 2 — Time Intelligence

All time intelligence measures require the active relationship between `fact_orders[order_date]` and `dim_date[Date]`.

```dax
-- YoY with VAR, SAMEPERIODLASTYEAR, ISBLANK guard
Revenue YoY % =
VAR CurrentRevenue = [Total Revenue]
VAR PriorRevenue =
    CALCULATE(
        [Total Revenue],
        SAMEPERIODLASTYEAR(dim_date[Date])
    )
RETURN
    IF(
        ISBLANK(PriorRevenue) || PriorRevenue = 0,
        BLANK(),
        DIVIDE(CurrentRevenue - PriorRevenue, PriorRevenue)
    )

-- Absolute YoY difference
Revenue YoY Abs =
VAR PriorRevenue =
    CALCULATE(
        [Total Revenue],
        SAMEPERIODLASTYEAR(dim_date[Date])
    )
RETURN [Total Revenue] - PriorRevenue

-- Rolling 3-month window using DATESINPERIOD
Revenue Rolling 3M =
CALCULATE(
    [Total Revenue],
    DATESINPERIOD(
        dim_date[Date],
        LASTDATE(dim_date[Date]),
        -3,
        MONTH
    )
)

-- Year-to-date cumulative revenue
Revenue YTD =
CALCULATE(
    [Total Revenue],
    DATESYTD(dim_date[Date])
)

-- Prior year YTD for comparison
Revenue YTD Prior Year =
CALCULATE(
    [Revenue YTD],
    SAMEPERIODLASTYEAR(dim_date[Date])
)

-- YTD vs prior YTD percentage
Revenue YTD vs PY % =
DIVIDE(
    [Revenue YTD] - [Revenue YTD Prior Year],
    [Revenue YTD Prior Year],
    BLANK()
)
```

---

## Group 3 — Dynamic Analysis

Uses RANKX, ALLSELECTED, ALLEXCEPT for context-aware calculations.

```dax
-- Revenue share respecting user's current filter selection
Revenue % of Total =
DIVIDE(
    [Total Revenue],
    CALCULATE([Total Revenue], ALLSELECTED()),
    0
)

-- Dynamic product ranking — updates with every filter applied
Product Revenue Rank =
IF(
    HASONEVALUE(dim_product[product_name]),
    RANKX(
        ALLSELECTED(dim_product[product_name]),
        [Total Revenue],
        ,
        DESC,
        DENSE
    )
)

-- Dynamic sub-category ranking
SubCategory Revenue Rank =
IF(
    HASONEVALUE(dim_product[sub_category]),
    RANKX(
        ALLSELECTED(dim_product[sub_category]),
        [Total Revenue],
        ,
        DESC,
        DENSE
    )
)

-- Flags top 10 products dynamically
Is Top 10 Product =
IF([Product Revenue Rank] <= 10, TRUE(), FALSE())

-- Revenue share within category (ALLEXCEPT removes sub-category filter only)
Revenue % of Category =
DIVIDE(
    [Total Revenue],
    CALCULATE(
        [Total Revenue],
        ALLEXCEPT(dim_product, dim_product[category])
    ),
    0
)

-- How far this product/segment's margin is from its category average
Profit Margin vs Category Avg =
VAR CurrentMargin = [Profit Margin %]
VAR CategoryAvgMargin =
    CALCULATE(
        [Profit Margin %],
        ALLEXCEPT(dim_product, dim_product[category])
    )
RETURN CurrentMargin - CategoryAvgMargin
```

---

## Group 4 — Customer Analytics

Uses AVERAGEX with context transition and FILTER for customer-level calculations.

```dax
-- Average revenue per customer using context transition
Avg Customer LTV =
AVERAGEX(
    VALUES(dim_customer[customer_id]),
    CALCULATE([Total Revenue])
)

-- Revenue divided by unique customers
Revenue per Customer =
DIVIDE([Total Revenue], [Total Customers], 0)

-- Share of revenue from High Value tier customers
High Value Revenue % =
DIVIDE(
    CALCULATE(
        [Total Revenue],
        dim_customer[customer_value_tier] = "High Value"
    ),
    [Total Revenue],
    0
)

-- Count of orders with negative profit
Loss-Making Orders =
CALCULATE(
    [Total Orders],
    fact_orders[is_profitable] = FALSE()
)

-- Loss-making orders as % of total
Loss-Making Orders % =
DIVIDE([Loss-Making Orders], [Total Orders], 0)

-- Avg days between order and shipment (AVERAGEX over unique orders)
Avg Days to Ship =
AVERAGEX(
    VALUES(fact_orders[order_id]),
    CALCULATE(MAX(fact_orders[days_to_ship]))
)

-- Customers whose first order falls within the selected period
New Customers =
CALCULATE(
    DISTINCTCOUNT(dim_customer[customer_id]),
    FILTER(
        dim_customer,
        dim_customer[first_order_date] >= MIN(dim_date[Date]) &&
        dim_customer[first_order_date] <= MAX(dim_date[Date])
    )
)

-- New customers as % of total
New Customers % =
DIVIDE([New Customers], [Total Customers], 0)
```

---

## Group 5 — Profitability & Discount Impact

Uses SUMX to iterate row-by-row and calculate discount effects at order level.

```dax
-- Total revenue given up to discounts (SUMX row-level calculation)
Revenue Lost to Discount =
SUMX(
    fact_orders,
    fact_orders[sales] * fact_orders[discount]
)

-- What revenue would be without any discount applied
Revenue at Full Price =
SUMX(
    fact_orders,
    fact_orders[sales] + (fact_orders[sales] * fact_orders[discount])
)

-- Estimated profit impact of discounts using margin_pct
Discount Impact on Profit =
SUMX(
    fact_orders,
    fact_orders[sales] * fact_orders[discount] * fact_orders[margin_pct]
)

-- Hypothetical profit if no discounts were applied
Profit if No Discount =
[Total Profit] - [Discount Impact on Profit]

-- Revenue coming from orders that generated a loss
Loss-Making Revenue =
CALCULATE(
    [Total Revenue],
    fact_orders[is_profitable] = FALSE()
)

-- Weighted average discount (weighted by sales value, more accurate than AVG)
Weighted Avg Discount =
DIVIDE(
    SUMX(fact_orders, fact_orders[discount] * fact_orders[sales]),
    [Total Revenue],
    0
)
```

---

## Group 6 — What-If Scenario (Discount Reduction Parameter)

Requires the `Discount Reduction` what-if parameter (numeric range 0–0.5, step 0.05).

```dax
-- Simulated revenue if discount is reduced by the parameter value
Simulated Revenue =
SUMX(
    fact_orders,
    VAR OriginalDiscount = fact_orders[discount]
    VAR ReducedDiscount = MAX(0, OriginalDiscount - [Discount Reduction Value])
    VAR OriginalSales = fact_orders[sales]
    VAR SimulatedSales = OriginalSales * (1 + OriginalDiscount) / (1 + ReducedDiscount)
    RETURN SimulatedSales
)

-- Gain from reducing discounts
Revenue Uplift =
[Simulated Revenue] - [Total Revenue]

-- Simulated profit margin after discount reduction
Simulated Profit Margin % =
VAR SimulatedProfit =
    SUMX(
        fact_orders,
        VAR OriginalDiscount = fact_orders[discount]
        VAR ReducedDiscount = MAX(0, OriginalDiscount - [Discount Reduction Value])
        VAR OriginalSales = fact_orders[sales]
        VAR SimulatedSales = OriginalSales * (1 + OriginalDiscount) / (1 + ReducedDiscount)
        VAR MarginGain = (SimulatedSales - OriginalSales) * fact_orders[margin_pct]
        RETURN fact_orders[profit] + MarginGain
    )
RETURN DIVIDE(SimulatedProfit, [Simulated Revenue], 0)
```

---

## Group 7 — Dynamic Titles & KPI Status

Text measures that change based on user filter selections.

```dax
-- Shows selected year or "All Years"
Selected Year Label =
IF(
    HASONEVALUE(dim_date[Year]),
    "Year " & SELECTEDVALUE(dim_date[Year]),
    "All Years"
)

-- Classifies YoY performance with directional label
Revenue KPI Status =
VAR Growth = [Revenue YoY %]
RETURN
    SWITCH(
        TRUE(),
        ISBLANK(Growth),    "—",
        Growth >= 0.1,      "▲ Strong Growth",
        Growth >= 0,        "▲ Growth",
        Growth >= -0.1,     "▼ Decline",
        "▼ Strong Decline"
    )

-- Classifies profit margin into performance tiers
Profit Margin Status =
VAR Margin = [Profit Margin %]
RETURN
    SWITCH(
        TRUE(),
        Margin >= 0.20,    "● Excellent",
        Margin >= 0.10,    "● Good",
        Margin >= 0,       "● Low",
        "● Negative"
    )

-- Dynamic title combining selected year and segment
Dynamic Title =
VAR SelectedYear =
    IF(HASONEVALUE(dim_date[Year]), FORMAT(SELECTEDVALUE(dim_date[Year]), "0"), "All Years")
VAR SelectedSegment =
    IF(HASONEVALUE(dim_customer[segment]), SELECTEDVALUE(dim_customer[segment]), "All Segments")
RETURN
    "Performance Overview · " & SelectedYear & " · " & SelectedSegment

-- Shows selected discount tier or "All Discount Tiers"
Discount Tier Label =
IF(
    HASONEVALUE(fact_orders[discount_tier]),
    SELECTEDVALUE(fact_orders[discount_tier]),
    "All Discount Tiers"
)
```
