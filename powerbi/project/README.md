# Power BI project (PBIP) — how to open it

This folder is a **Power BI Project**: the semantic model as text rather than as a binary `.pbix`. Opening it in Power BI Desktop builds the whole model — Power Query, relationships and every DAX measure — so the only work left is placing visuals.

---

## Open it

1. **Enable the format once.** Power BI Desktop ▸ **File ▸ Options and settings ▸ Options ▸ Preview features** ▸ tick **Power BI Project (.pbip) save option** ▸ OK ▸ restart Desktop.
2. **File ▸ Open ▸ Browse** ▸ select `SaaS_Financial_KPIs.pbip`.
3. **Point it at the data.** The file path is a parameter, so it is set in one place:
   **Home ▸ Transform data ▸ Manage Parameters ▸ `p_DataPath`** ▸ paste the full path to `data/superstore.csv` on your machine, e.g.

   ```
   C:\Users\<you>\github-portfolio\saas-financial-kpis\data\superstore.csv
   ```

   ▸ **Close & Apply**.
4. **Refresh.** Every table loads from the CSV.

---

## What you get

| | |
|---|---|
| **Tables** | `fact_orders`, `dim_date`, `dim_customer`, `dim_product`, `dim_geography`, `Discount Reduction` |
| **Relationships** | 5 — including an **inactive** one on `ship_date`, so shipping analysis is available via `USERELATIONSHIP` without disturbing the default date context |
| **Measures** | 40, in display folders (Core · Time Intelligence · Dynamic · Customer · Discount · What-If · Labels) |
| **Report pages** | 5, named and empty, ready for visuals |

Expected after refresh: **9,994 rows** in `fact_orders`, **793** customers, **1,862** products, **632** geography rows, **US$2,297,201** total revenue, **12.47%** margin, dates **2015–2018**.

If those numbers match, the model loaded correctly.

---

## Then build the visuals

Follow [`../build_guide.md`](../build_guide.md) — it goes page by page. The five pages already exist with the right names; you are placing visuals onto them, not starting from a blank file.

Two settings the model already carries, so you do not need to redo them:

- `dim_date` is marked as a **date table** (`dataCategory: Time`, `Date` as key) — this is what makes `SAMEPERIODLASTYEAR`, `DATESYTD` and `DATESINPERIOD` behave.
- Sort-by columns are set: `Month` → `Month Number`, `Year Month` → `Year Month Sort`, `Quarter` → `Quarter Number`, `customer_value_tier` → its sort column, `discount_tier` → its sort column. Without these, months sort alphabetically (Apr, Aug, Dec…).

Turn **Options ▸ Data Load ▸ Auto Date/Time** *off* if it is on — it creates a hidden calendar per date column and competes with `dim_date`.

---

## If it does not open

This project was authored as text and **has not been opened in Power BI Desktop** — the format is version-sensitive, so a mismatch is possible. If Desktop refuses it:

1. Note the exact error message.
2. Fall back to building the model by hand — [`../power_query.md`](../power_query.md) has every M query and [`../measures.md`](../measures.md) every DAX measure, in the order they load. Nothing is lost; it is the same model, entered manually.

---

## Two known data quirks

- **32 product IDs carry more than one product name** in the source. `dim_product` resolves each with `List.First`, which picks one arbitrarily. Product-level reporting is fine; a report on those 32 specific IDs would need a canonicalisation rule.
- **`ship_date` runs to 2019-01-05**, past the last order date. `dim_date` is generated from the first order year to the last *ship* year, so both relationships stay complete.
