# DAX Measures

Complete documentation of all DAX measures in the Power BI model.
Organized in 6 groups by analytical purpose.

---

## Data Model

Star schema modeled in Power BI from the single `data/superstore.csv` file — the
dimensions are shaped in Power Query (M), which is where the modeling value is:
- `fact_orders` — one row per order line (loaded from `data/superstore.csv`)
- `dim_customer` — one row per customer with value tier classification
- `dim_product` — one row per product with revenue rank and profitability flag
- `dim_date` — full date dimension generated in Power Query M (2015–2018)

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

All of these anchor on **`MAX(fact_orders[order_date])`** — the last date on which a sale
actually happened — never on the end of the date table. And none of them use `DATESYTD`,
`SAMEPERIODLASTYEAR` or `DATESINPERIOD`. Both choices were paid for:

- **Anchoring on the calendar's last date is a trap.** The calendar covers whole years, so
  its last date sits in December of the final year even when the data stops earlier. Get
  the calendar's upper bound wrong by one year and every measure here returns blank while
  the *prior year* measure still returns a number — which surfaces as a KPI reading exactly
  **−100%**, not as an error.
- **The time-intelligence functions need a marked date table and a contiguous date
  selection.** When either condition fails they raise an error, and with
  `returnErrorValuesAsNull` set on the model that error arrives as a silent blank. Explicit
  date arithmetic has no such preconditions.

```dax
-- Revenue in the year of the last sale, up to that date
Revenue YTD =
VAR LastDay = MAX(fact_orders[order_date])
VAR YearStart = DATE(YEAR(LastDay), 1, 1)
RETURN
    IF(
        ISBLANK(LastDay),
        BLANK(),
        CALCULATE(
            [Total Revenue],
            FILTER(ALL(dim_date), dim_date[Date] >= YearStart && dim_date[Date] <= LastDay)
        )
    )

-- The same window one year earlier, so the comparison is like for like
Revenue YTD Prior Year =
VAR LastDay = MAX(fact_orders[order_date])
VAR PriorStart = DATE(YEAR(LastDay) - 1, 1, 1)
VAR PriorEnd = DATE(YEAR(LastDay) - 1, MONTH(LastDay), DAY(LastDay))
RETURN
    IF(
        ISBLANK(LastDay),
        BLANK(),
        CALCULATE(
            [Total Revenue],
            FILTER(ALL(dim_date), dim_date[Date] >= PriorStart && dim_date[Date] <= PriorEnd)
        )
    )

Revenue YTD vs PY % =
DIVIDE([Revenue YTD] - [Revenue YTD Prior Year], [Revenue YTD Prior Year], BLANK())

-- Trailing three months. The window is expressed as the integer YYYYMM the date table
-- already carries: DATE(year, month - 2, 1) is an error in January and February, and one
-- errored month is enough to break the whole visual.
Revenue Rolling 3M =
VAR LastDay = MAX(fact_orders[order_date])
VAR Y = YEAR(LastDay)
VAR M = MONTH(LastDay)
VAR StartYM = IF(M >= 3, Y * 100 + M - 2, (Y - 1) * 100 + M + 10)
RETURN
    IF(
        ISBLANK(LastDay),
        BLANK(),
        CALCULATE(
            [Total Revenue],
            FILTER(
                ALL(dim_date),
                dim_date[Year Month Sort] >= StartYM && dim_date[Date] <= LastDay
            )
        )
    )

-- Year over year, compared on the Year column rather than a shifted date range.
-- Blank on the first year is correct: there is nothing to compare against.
Revenue YoY % =
VAR Y = YEAR(MAX(fact_orders[order_date]))
VAR Cur = CALCULATE([Total Revenue], FILTER(ALL(dim_date), dim_date[Year] = Y))
VAR Prev = CALCULATE([Total Revenue], FILTER(ALL(dim_date), dim_date[Year] = Y - 1))
RETURN
    IF(ISBLANK(Prev) || Prev = 0, BLANK(), DIVIDE(Cur - Prev, Prev))

Revenue YoY Abs =
VAR Y = YEAR(MAX(fact_orders[order_date]))
VAR Cur = CALCULATE([Total Revenue], FILTER(ALL(dim_date), dim_date[Year] = Y))
VAR Prev = CALCULATE([Total Revenue], FILTER(ALL(dim_date), dim_date[Year] = Y - 1))
RETURN Cur - Prev
```

Verified against the source file: `Revenue YTD` = US$733,215 (2018), `Revenue YTD vs PY %`
= +20.5% against US$608,474 through 2017-12-30, `Revenue Rolling 3M` = US$280,054
(Oct–Dec 2018), and yearly growth of −2.8%, +29.5%, +20.4%.

---

## Group 0 — Model health checks

Three measures that exist to answer "is the model wired up?" without opening a query
window. They earned their place while debugging a date table that silently overshot into
an empty year.

```dax
Diag Date Rows = COUNTROWS(dim_date)

Diag Date Span =
FORMAT(MIN(dim_date[Date]), "yyyy-mm-dd") & "  ->  " & FORMAT(MAX(dim_date[Date]), "yyyy-mm-dd")

-- If this returns the grand total instead of 2018's revenue, the date relationship is
-- not propagating; if it returns blank, no rows match between the two tables.
Diag Revenue 2018 by Date = CALCULATE([Total Revenue], dim_date[Year] = 2018)
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

-- Customers whose first order falls within the selected period.
-- The period boundaries are captured in VARs first: read inside FILTER they would be
-- evaluated in the row context of dim_customer, which is not the same question.
New Customers =
VAR PeriodStart = MIN(dim_date[Date])
VAR PeriodEnd = MAX(dim_date[Date])
RETURN
    IF(
        ISBLANK(PeriodStart) || ISBLANK(PeriodEnd),
        BLANK(),
        CALCULATE(
            DISTINCTCOUNT(dim_customer[customer_id]),
            FILTER(
                ALLSELECTED(dim_customer),
                dim_customer[first_order_date] >= PeriodStart
                    && dim_customer[first_order_date] <= PeriodEnd
            )
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
