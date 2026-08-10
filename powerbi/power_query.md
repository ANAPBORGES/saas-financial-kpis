# Power Query (M) — Transformations

Every query behind the model, in full M. Paste each block into
**Home ▸ Transform data ▸ New Source ▸ Blank Query ▸ Advanced Editor**.

The design goal is that **all shaping happens in Power Query, not in DAX**.
Calculated columns are avoided entirely: dimensions are built by grouping the
source, and the fact table carries only pre-computed, storage-friendly columns.
This keeps the model small and every measure in `measures.md` a pure aggregation.

**Load order:** `p_DataPath` → `src_superstore` → the four dimensions → `fact_orders`.

---

## 0 — Parameter: `p_DataPath`

**Home ▸ Manage Parameters ▸ New Parameter.** Name `p_DataPath`, type *Text*,
current value = the full path to `data/superstore.csv` on your machine.

Everything reads the file through this parameter, so moving the repo means
editing one value instead of every query. Suggested value:

```
C:\...\saas-financial-kpis\data\superstore.csv
```

---

## 1 — `src_superstore` (staging)

Loads and types the raw CSV. **Right-click ▸ uncheck "Enable load"** — this query
feeds the others and must not become a table in the model.

```m
let
    Source = Csv.Document(
        File.Contents(p_DataPath),
        [Delimiter = ",", Columns = 21, Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed = Table.TransformColumnTypes(
        Promoted,
        {
            {"Row ID", Int64.Type},
            {"Order ID", type text},
            {"Order Date", type date},
            {"Ship Date", type date},
            {"Ship Mode", type text},
            {"Customer ID", type text},
            {"Customer Name", type text},
            {"Segment", type text},
            {"Country", type text},
            {"City", type text},
            {"State", type text},
            {"Postal Code", type text},
            {"Region", type text},
            {"Product ID", type text},
            {"Category", type text},
            {"Sub-Category", type text},
            {"Product Name", type text},
            {"Sales", type number},
            {"Quantity", Int64.Type},
            {"Discount", type number},
            {"Profit", type number}
        },
        "en-US"
    ),
    Buffered = Table.Buffer(Typed)
in
    Buffered
```

**Two deliberate choices:**

- **`Postal Code` stays text.** Typed as a number it would drop the leading zero
  on north-eastern ZIPs (`01star` → `1star`). Postal codes are labels, not
  quantities — they are never summed.
- **`Table.Buffer`** loads the CSV into memory once. Five downstream queries
  read this source; without buffering the file is parsed five times.

The dates in the CSV are ISO (`2017-11-08`), so `"en-US"` parses them
unambiguously regardless of the machine's regional settings.

---

## 2 — `dim_date` (generated in M, not DAX)

A calendar built from the data's own range, so it never needs manual editing.

The upper bound is the last **order** date, deliberately. Bounding it by the last
*ship* date looks tidier — 42 December-2018 orders ship in January 2019, and the
inactive `ship_date` relationship then has no unmatched dates — but it extends the
calendar to 2019-12-31 and creates a **whole year with no sales**. That year then
becomes the last date in the model, and every measure anchored on the end of the
calendar silently returns blank, while `Year` slicers offer a value that empties the
report. A phantom year in every date filter costs more than 42 unmatched ship dates
on a relationship nothing activates.

```m
let
    MinDate    = List.Min(src_superstore[Order Date]),
    MaxDate    = List.Max(src_superstore[Order Date]),
    StartDate  = #date(Date.Year(MinDate), 1, 1),
    EndDate    = #date(Date.Year(MaxDate), 12, 31),
    DayCount   = Duration.Days(EndDate - StartDate) + 1,
    DateList   = List.Dates(StartDate, DayCount, #duration(1, 0, 0, 0)),
    ToTable    = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}, null, ExtraValues.Error),
    TypedDate  = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),

    AddYear        = Table.AddColumn(TypedDate,      "Year",            each Date.Year([Date]), Int64.Type),
    AddMonthNo     = Table.AddColumn(AddYear,        "Month Number",    each Date.Month([Date]), Int64.Type),
    AddMonth       = Table.AddColumn(AddMonthNo,     "Month",           each Date.ToText([Date], "MMM", "en-US"), type text),
    AddYearMonth   = Table.AddColumn(AddMonth,       "Year Month",      each Date.ToText([Date], "yyyy-MM"), type text),
    AddYearMonthNo = Table.AddColumn(AddYearMonth,   "Year Month Sort", each Date.Year([Date]) * 100 + Date.Month([Date]), Int64.Type),
    AddQuarter     = Table.AddColumn(AddYearMonthNo, "Quarter",         each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddQuarterNo   = Table.AddColumn(AddQuarter,     "Quarter Number",  each Date.QuarterOfYear([Date]), Int64.Type),
    AddDayOfWeek   = Table.AddColumn(AddQuarterNo,   "Day of Week",     each Date.ToText([Date], "ddd", "en-US"), type text),
    AddIsWeekend   = Table.AddColumn(AddDayOfWeek,   "Is Weekend",      each Date.DayOfWeek([Date], Day.Monday) >= 5, type logical)
in
    AddIsWeekend
```

**Why generate the calendar instead of using Auto Date/Time:** Power BI's automatic
date tables create one hidden calendar *per date column* and cannot be shared,
sorted, or extended. A single explicit `dim_date` is what makes `SAMEPERIODLASTYEAR`,
`DATESYTD` and `DATESINPERIOD` in [`measures.md`](./measures.md) behave predictably.

> **Two required follow-ups in the model view:**
> 1. Select `dim_date` ▸ **Table tools ▸ Mark as date table** ▸ Date column = `Date`.
> 2. Select `Month` ▸ **Column tools ▸ Sort by column** ▸ `Month Number`.
>    Do the same for `Year Month` → `Year Month Sort`.
>    Without this, months sort alphabetically (Apr, Aug, Dec…).
>
> Also turn **File ▸ Options ▸ Data Load ▸ Auto Date/Time** *off*.

---

## 3 — `dim_customer`

One row per customer, with lifetime aggregates and a value tier.

```m
let
    Source = src_superstore,
    Grouped = Table.Group(
        Source,
        {"Customer ID"},
        {
            {"customer_name",     each List.First([Customer Name]), type text},
            {"segment",           each List.First([Segment]), type text},
            {"first_order_date",  each List.Min([Order Date]), type date},
            {"last_order_date",   each List.Max([Order Date]), type date},
            {"lifetime_revenue",  each List.Sum([Sales]), type number},
            {"lifetime_profit",   each List.Sum([Profit]), type number},
            {"order_count",       each List.Count(List.Distinct([Order ID])), Int64.Type}
        }
    ),
    Renamed = Table.RenameColumns(Grouped, {{"Customer ID", "customer_id"}}),

    AddTier = Table.AddColumn(
        Renamed,
        "customer_value_tier",
        each if [lifetime_revenue] >= 5000 then "High Value"
             else if [lifetime_revenue] >= 1500 then "Mid Value"
             else "Low Value",
        type text
    ),
    AddTierSort = Table.AddColumn(
        AddTier,
        "customer_value_tier_sort",
        each if [customer_value_tier] = "High Value" then 1
             else if [customer_value_tier] = "Mid Value" then 2
             else 3,
        Int64.Type
    ),
    AddMargin = Table.AddColumn(
        AddTierSort,
        "lifetime_margin_pct",
        each if [lifetime_revenue] = 0 then 0 else [lifetime_profit] / [lifetime_revenue],
        type number
    ),
    AddTenure = Table.AddColumn(
        AddMargin,
        "tenure_days",
        each Duration.Days([last_order_date] - [first_order_date]),
        Int64.Type
    )
in
    AddTenure
```

The thresholds are business rules and belong in the brief, not in the code —
they are written here so they are visible and easy to change. If they should
follow the distribution instead of fixed values, the deciles are already
computed in [`sql/08_customer_value_tiers.sql`](../sql/08_customer_value_tiers.sql).

`customer_value_tier_sort` exists so the tier sorts High → Mid → Low instead of
alphabetically (High, Low, Mid). Apply **Sort by column** on it.

Feeds `[High Value Revenue %]`, `[New Customers]` and `[Avg Customer LTV]`.

---

## 4 — `dim_product`

```m
let
    Source = src_superstore,
    Grouped = Table.Group(
        Source,
        {"Product ID"},
        {
            {"product_name",  each List.First([Product Name]), type text},
            {"category",      each List.First([Category]), type text},
            {"sub_category",  each List.First([#"Sub-Category"]), type text},
            {"total_revenue", each List.Sum([Sales]), type number},
            {"total_profit",  each List.Sum([Profit]), type number},
            {"units_sold",    each List.Sum([Quantity]), Int64.Type}
        }
    ),
    Renamed = Table.RenameColumns(Grouped, {{"Product ID", "product_id"}}),
    AddIsProfitable = Table.AddColumn(
        Renamed,
        "is_profitable_product",
        each [total_profit] > 0,
        type logical
    ),
    AddMargin = Table.AddColumn(
        AddIsProfitable,
        "product_margin_pct",
        each if [total_revenue] = 0 then 0 else [total_profit] / [total_revenue],
        type number
    ),
    Sorted   = Table.Sort(AddMargin, {{"total_revenue", Order.Descending}}),
    AddRank  = Table.AddIndexColumn(Sorted, "revenue_rank", 1, 1, Int64.Type)
in
    AddRank
```

> **Data-quality note — `product_name` is not clean.** 32 of the 1,862 product IDs
> carry more than one spelling of the product name in the source (e.g. the same ID
> appearing with and without a trailing size). `List.First` therefore picks *a*
> name, not a guaranteed-consistent one. That is fine here because the **ID** is the
> key and drives every join and rank; the name is only a display label. If you ever
> need a canonical name, replace `List.First([Product Name])` with the most frequent
> spelling:
> ```m
> each let t = Table.Group(_, {"Product Name"}, {{"n", Table.RowCount}})
>      in Table.Sort(t, {{"n", Order.Descending}}){0}[Product Name]
> ```
> The grouping on `Product ID` (not on ID + name) already guarantees exactly 1,862
> rows regardless — grouping on both would split those 32 into duplicate keys and
> break the relationship. This is exactly the kind of dirty-key issue a star schema
> forces you to confront up front.

`revenue_rank` here is a **static** rank over the whole dataset — useful as a
slicer ("show me the top 50 products"). It is deliberately *not* the same thing as
`[Product Revenue Rank]` in `measures.md`, which is a `RANKX` measure that
recalculates under whatever filters the user applies. Having both is the point:
one is a stable attribute, the other is context-aware.

> **`[#"Sub-Category"]`, not `[Sub-Category]`.** A hyphen is not allowed in an M
> identifier, so the bare form fails to parse with *"Invalid identifier"*. Column
> names with hyphens have to be written as quoted identifiers. Names with plain
> spaces — `[Order Date]` — are fine unquoted.

---

## 5 — `dim_geography`

```m
let
    Source   = src_superstore,
    Selected = Table.SelectColumns(Source, {"Country", "Region", "State", "City", "Postal Code"}),
    Grouped  = Table.Group(
        Selected,
        {"State", "City"},
        {
            {"country",       each List.First([Country]), type text},
            {"region",        each List.First([Region]), type text},
            {"postal_codes",  each Text.Combine(List.Distinct([Postal Code]), ", "), type text}
        }
    ),
    AddKey   = Table.AddColumn(Grouped, "geo_key", each [State] & "|" & [City], type text),
    Renamed  = Table.RenameColumns(AddKey, {{"State", "state"}, {"City", "city"}}),
    Reordered = Table.SelectColumns(Renamed, {"geo_key", "country", "region", "state", "city", "postal_codes"})
in
    Reordered
```

Grouping on `State, City` (rather than `Table.Distinct` on every column)
guarantees `geo_key` is unique — a city can carry several postal codes, which
would otherwise produce duplicate keys and break the relationship.

---

## 6 — `fact_orders`

The fact table: one row per order line, keys plus measures plus the engineered
columns the DAX depends on.

```m
let
    Source = src_superstore,

    AddGeoKey = Table.AddColumn(Source, "geo_key", each [State] & "|" & [City], type text),

    AddDaysToShip = Table.AddColumn(
        AddGeoKey,
        "days_to_ship",
        each Duration.Days([Ship Date] - [Order Date]),
        Int64.Type
    ),
    AddIsProfitable = Table.AddColumn(
        AddDaysToShip,
        "is_profitable",
        each [Profit] > 0,
        type logical
    ),
    AddMarginPct = Table.AddColumn(
        AddIsProfitable,
        "margin_pct",
        each if [Sales] = 0 then 0 else [Profit] / [Sales],
        type number
    ),
    AddDiscountTier = Table.AddColumn(
        AddMarginPct,
        "discount_tier",
        each if [Discount] = 0 then "No Discount"
             else if [Discount] <= 0.10 then "1-10%"
             else if [Discount] <= 0.20 then "11-20%"
             else if [Discount] <= 0.30 then "21-30%"
             else "Over 30%",
        type text
    ),
    AddDiscountTierSort = Table.AddColumn(
        AddDiscountTier,
        "discount_tier_sort",
        each if [Discount] = 0 then 1
             else if [Discount] <= 0.10 then 2
             else if [Discount] <= 0.20 then 3
             else if [Discount] <= 0.30 then 4
             else 5,
        Int64.Type
    ),

    Renamed = Table.RenameColumns(
        AddDiscountTierSort,
        {
            {"Order ID", "order_id"},
            {"Order Date", "order_date"},
            {"Ship Date", "ship_date"},
            {"Ship Mode", "ship_mode"},
            {"Customer ID", "customer_id"},
            {"Product ID", "product_id"},
            {"Sales", "sales"},
            {"Quantity", "quantity"},
            {"Discount", "discount"},
            {"Profit", "profit"}
        }
    ),
    Kept = Table.SelectColumns(
        Renamed,
        {
            "order_id", "order_date", "ship_date", "ship_mode",
            "customer_id", "product_id", "geo_key",
            "sales", "quantity", "discount", "profit",
            "days_to_ship", "is_profitable", "margin_pct",
            "discount_tier", "discount_tier_sort"
        }
    )
in
    Kept
```

**`Table.SelectColumns` at the end is not cosmetic.** It drops `Customer Name`,
`Product Name`, `Category`, `State`, `City`, `Region`, `Row ID` and the rest from
the fact table — they now live in the dimensions. Descriptive text repeated across
9,994 rows compresses badly in VertiPaq; the same text stored once per dimension
row does not. This is the practical reason to build a star schema at this size.

Apply **Sort by column** on `discount_tier` → `discount_tier_sort`.

---

## 7 — What-if parameter: `Discount Reduction`

**Modeling ▸ New parameter ▸ Numeric range.** Name `Discount Reduction`,
Minimum `0`, Maximum `0.5`, Increment `0.05`, Default `0`.

This one is not written in M — Power BI generates a DAX table and the
`[Discount Reduction Value]` measure that Group 6 of `measures.md` consumes:

```dax
Discount Reduction = GENERATESERIES(0, 0.5, 0.05)

Discount Reduction Value = SELECTEDVALUE('Discount Reduction'[Discount Reduction], 0)
```

Format the column as **Percentage** so the slicer reads "15%" rather than "0.15".

---

## Refresh check

After **Close & Apply**, these should hold — they are the numbers verified
directly against the CSV:

| Check | Expected |
|---|---|
| `fact_orders` row count | 9,994 |
| `dim_customer` row count | 793 |
| `[Total Orders]` | 5,009 |
| `[Total Revenue]` | 2,297,200.86 |
| `[Total Profit]` | 286,397.02 |
| `[Profit Margin %]` | 12.47% |
| `dim_date` range | 2015-01-01 → 2018-12-31 |

If `[Total Revenue]` is right but `[Total Orders]` reads 9,994, the measure is
counting rows instead of distinct `order_id` — check `DISTINCTCOUNT`.
