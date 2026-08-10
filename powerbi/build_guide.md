# Build Guide — assembling the report in Power BI Desktop

Turns the documented model and measures into the interactive report. Nothing here
needs an account — [Power BI Desktop](https://www.microsoft.com/power-platform/products/power-bi/desktop)
is free. Budget ~3–4 hours end to end.

The order matters: **theme → data → model → measures → visuals → interactions**.
Each step assumes the previous one is done.

---

## Step 1 — Apply the theme first

**View ▸ Themes** — pick a theme with a clear categorical palette, and keep it
consistent across all pages.

Doing this before adding any visual means every chart is born on-brand — data
colours, card typography and gridlines are already set, so you are never
recolouring by hand.

---

## Step 2 — Load and shape the data

Follow [`power_query.md`](./power_query.md) top to bottom:

1. Create the `p_DataPath` parameter pointing at your local `data/superstore.csv`.
2. Build `src_superstore` (disable load).
3. Build `dim_date`, `dim_customer`, `dim_product`, `dim_geography`, `fact_orders`.
4. **Close & Apply.**

Then the model settings in [`data_model.md`](./data_model.md#required-model-settings) —
Mark as date table, the five Sort-by-column pairs, Auto Date/Time off. These are
silent-failure settings: skip one and a chart sorts wrong with no error.

---

## Step 3 — Build the relationships

**Model view.** Drag the keys to match the relationships table in
[`data_model.md`](./data_model.md#relationships). You should end with a clean star:
`fact_orders` in the middle, four dimensions around it, all one-to-many, all
single-direction. Add `ship_date → dim_date[Date]` and set it **inactive** (dashed line).

---

## Step 4 — Create the measures

Paste every measure from [`measures.md`](./measures.md). Keep them in one dedicated
**"_Measures"** table (New Table ▸ `_Measures = {BLANK()}`, then create measures into
it) so they group separately from columns in the field list.

Add the `Discount Reduction` what-if parameter last (Modeling ▸ New parameter ▸
Numeric range) — it generates `[Discount Reduction Value]`, which Group 6 needs.

**Validate before drawing anything.** Drop `[Total Revenue]`, `[Total Orders]`,
`[Total Customers]`, `[Profit Margin %]` into a card each and check them against the
table in [`data_model.md`](./data_model.md#validation). If the numbers are wrong,
fix them now — every visual inherits the error otherwise.

---

## Step 5 — The pages, as built

The report has six pages. This is what each one carries; the measures are all in
[`measures.md`](./measures.md).

| Page | Visuals |
|---|---|
| **Home** | cover image with five navigation buttons |
| **Executive Summary** | five KPI cards (revenue, profit, margin, orders, average order value) · revenue by month · revenue by region · revenue and margin by category · growth year over year with the YoY line · four slicers |
| **Revenue & Growth** | year-to-date and prior-year cards, the 3-month figure and the growth reading · monthly revenue with the 3-month trend · revenue by year · revenue against profit · margin over time |
| **Customers** | value-per-customer cards · revenue by segment · the base by value tier · new customers by year · margin by segment × region · every account ranked with its margin |
| **Products** | margin by product line (matrix) · product by product (table) · discount against margin by sub-category (scatter) · weight inside the category |
| **Discount Impact** | the what-if slider · revenue given up to discount, simulated gain, simulated margin and weighted discount · loss rate and revenue by discount band · revenue given up by line and by region |

Shared on every analysis page: a header image with navigation, and a footer declaring
source, period and scope.

**Two notes worth carrying into any build of this kind.** A KPI card whose measure resolves
against the *end of the date table* reads blank the moment the calendar overshoots the data —
see the time-intelligence group in `measures.md`. And a "new customers" card with no year
selected is always 100% of the base; as a chart by year it tells the actual story, which here
is that acquisition fell from 595 in 2015 to 11 in 2018.

---

## Step 6 — Add the interactions (this is what was missing)

The old build had **none of these**. They are what separate a report from four
static pages, and each is quick:

**Slicers.** Add a slicer panel to each page: `dim_date[Year]` (as buttons),
`dim_customer[segment]`, `dim_geography[region]`, `dim_product[category]`. Then
**View ▸ Sync slicers** and tick every page so one selection filters them all.

**Drill-through — customer detail.** New page named `Customer Detail`. Add a
drill-through filter on `dim_customer[customer_id]`. Put the customer's KPI cards,
their monthly revenue line, and their orders table on it. Now right-clicking any
customer on any page offers "Drill through ▸ Customer Detail." Add a Back button
(Insert ▸ Buttons ▸ Back).

**Custom tooltip page.** New page, **Page information ▸ Allow use as tooltip = On**,
canvas size **Tooltip**. Put a mini revenue-trend line + `[Profit Margin %]` card on
it. On the MRR bar chart, **Format ▸ Tooltip ▸ Type = Report page ▸** that page. Now
hovering a bar shows a rich card, not just a number.

**Bookmarks.** View ▸ Bookmarks. Create bookmarks for saved filter states (e.g.
"West region", "High-value customers") and wire them to buttons for one-click views.
Use the Selection pane to show/hide a slicer panel behind a filter icon.

**Field parameters** (impressive, and new-ish). Modeling ▸ New parameter ▸ Fields.
Bundle `[Total Revenue]`, `[Total Profit]`, `[Total Orders]` into a "Metric" selector
and a dropdown lets the viewer swap what a chart plots. Bundle
`segment / region / category` into a "Breakdown" selector for the axis.

**Conditional formatting.** On the segment/region bars, Format ▸ Data colors ▸
fx ▸ rules, using `[Profit Margin Status]` so negative-margin bars turn red. Ties
the visual to the status palette in the theme.

---

## Step 7 — Re-shoot the screenshots

The current PNGs in `assets/` are from an earlier data vintage (they show 2014–2017
and "2 Mil" customers; the real data is 2015–2018 and 793 customers). Once the
report is rebuilt:

1. Set a clean filter state (e.g. All Years).
2. Screenshot each page at a consistent width.
3. Replace the four files in `assets/` keeping the same names, so the README
   embeds update automatically.
4. Optionally record a short GIF of the slicers + drill-through + what-if slider in
   action (ScreenToGif, keep it under 5 MB) — that is the artefact that proves
   interactivity a static PNG cannot.

---

