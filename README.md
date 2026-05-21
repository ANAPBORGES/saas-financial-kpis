# SaaS Financial KPIs 💰
> End-to-end financial analysis of a retail dataset applying SaaS metrics — MRR, churn, retention, customer value, discount impact, and segment performance.

[![SQL](https://img.shields.io/badge/SQL-BigQuery-4285F4?style=flat&logo=google-cloud)](https://cloud.google.com/bigquery)
[![Dashboard](https://img.shields.io/badge/Dashboard-Power%20BI-F2C811?style=flat&logo=powerbi)](./superstore-financial-kpis.pbix)
[![Status](https://img.shields.io/badge/Status-Complete-success?style=flat)]()

---

## 📌 Business Context

**Industry:** Retail / SaaS-inspired analytics
**Stakeholders:** Finance, Commercial, and C-level teams
**Business question:** *How does revenue evolve over time, which customers and segments drive the most value, and where is profitability being eroded by discounting?*

This project analyzes 4 years of sales data from the Superstore dataset (2014–2017), applying SaaS financial metrics to a retail context. Beyond standard MRR and churn analysis, the project deep-dives into discount impact on profitability, customer value tiers, sub-category Pareto analysis, and regional efficiency — delivering insights that support strategic decisions across revenue planning, pricing, and customer retention.

---

## 🎯 Objectives

- [x] Analyze MRR trends with MoM growth, 3-month rolling average, and YTD cumulative revenue
- [x] Calculate customer churn and retention rates with boundary-year correction
- [x] Identify the discount threshold above which orders become loss-making
- [x] Rank customers by revenue and profitability using NTILE and PERCENTILE_CONT
- [x] Perform Pareto analysis on sub-categories with cumulative revenue share
- [x] Analyze regional performance with profit efficiency (profit per order)
- [x] Deliver a multi-page Power BI dashboard with DAX time intelligence measures

---

## 🗂 Dataset

| Field | Details |
|---|---|
| **Source** | [Kaggle — Superstore Sales Dataset](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final) |
| **Size** | ~10K orders, 1 table |
| **Period** | January 2014 – December 2017 |

**Key fields used:**
- `Order Date` — monthly and yearly time series
- `Sales` — MRR and revenue calculations
- `Profit` — margin and profitability analysis
- `Discount` — discount impact analysis
- `Customer ID` — churn, retention, and customer value
- `Segment` — Consumer, Corporate, Home Office
- `Region` — West, East, Central, South
- `Sub-Category` — Pareto analysis

---

## 🔧 Technical Approach

### Data Model

```
Kaggle Superstore CSV
        │
        ▼
BigQuery: analytics-portfolio-496419.superstore.orders   ← raw table (~10K rows)
        │
        ├── vw_mrr               ← monthly MRR, orders, customers, margin
        ├── vw_churn             ← yearly retention and churn (cohort self-join)
        └── vw_segments          ← revenue and profit by segment, region, YoY growth
                │
                ▼
        Power BI Desktop (4 pages: Home · MRR · Churn · Segments)
        DAX measures: time intelligence, rolling averages, dynamic rankings
```

### SQL Queries

| Query | Description |
|---|---|
| [`01_mrr.sql`](./sql/01_mrr.sql) | Monthly MRR, active customers and profit margin |
| [`02_churn.sql`](./sql/02_churn.sql) | Yearly churn and retention — cohort self-join |
| [`03_nrr_segments.sql`](./sql/03_nrr_segments.sql) | Revenue by segment and region with YoY growth |
| [`04_mrr_advanced.sql`](./sql/04_mrr_advanced.sql) | MoM growth (LAG) + 3M rolling avg + YTD cumulative + growth acceleration |
| [`05_subcategory_pareto.sql`](./sql/05_subcategory_pareto.sql) | Sub-category Pareto — cumulative share, profitability flag, YoY growth |
| [`06_regional_performance.sql`](./sql/06_regional_performance.sql) | Regional deep dive — RANK, profit per order, revenue share, YoY |
| [`07_discount_impact.sql`](./sql/07_discount_impact.sql) | Discount tier analysis — loss rate per tier, margin erosion by segment |
| [`08_customer_value.sql`](./sql/08_customer_value.sql) | Customer ranking — NTILE deciles, PERCENTILE_CONT tiers, value vs profitability |

### Power BI Implementation

| Document | Description |
|---|---|
| [`powerbi/measures.md`](./powerbi/measures.md) | DAX measures: time intelligence, rolling avg, YoY, rankings, churn |
| [`powerbi/data_model.md`](./powerbi/data_model.md) | View schemas, Power Query transformations, and custom visuals |

---

## 📈 Key Findings

1. **51% revenue growth over 4 years** — MRR grew from $40K/month (2014) to $61K/month (2017), with 3-month rolling avg revealing consistent upward momentum
2. **Retention improving year over year** — churn dropped from 26% (2014) to 12% (2016); 2017 excluded from churn calculation as the dataset ends that year
3. **Discounting is eroding profitability** — orders with >30% discount have a loss rate above 70%; the break-even discount level is approximately 20%
4. **Consumer segment dominates revenue** — Consumer = ~50% of total revenue ($1.16M), but Corporate has a higher profit margin per order
5. **West region leads in revenue and profit** — West generates $725K and the highest profit per order; South lags with lower efficiency
6. **Top 5 sub-categories = 60% of revenue** — classic Pareto concentration; Tables sub-category is the most loss-making despite significant revenue

---

## 📊 Dashboard

**Tool:** Power BI Desktop
**File:** [Download .pbix](./superstore-financial-kpis.pbix)

| Page | Description |
|---|---|
| **Home** | Summary navigation with key metrics |
| **MRR** | Monthly revenue + 3M rolling avg · Active customers trend · Profit margin evolution |
| **Churn** | Yearly retention vs churn · Cohort area chart · Retained vs churned breakdown |
| **Segments** | Revenue and profit by segment and region · YoY growth comparison |

**Previews:**

| Home | MRR |
|---|---|
| ![Home](./assets/Home.png) | ![MRR](./assets/MRR.png) |

| Churn | Segments |
|---|---|
| ![Churn](./assets/Churn.png) | ![Segments](./assets/Segments.png) |

---

## 📁 Repository Structure

```
saas-financial-kpis/
│
├── sql/
│   ├── 01_mrr.sql                   ← MRR, active customers, profit margin by month
│   ├── 02_churn.sql                 ← Churn/retention cohort (yearly self-join)
│   ├── 03_nrr_segments.sql          ← Segment revenue with YoY growth
│   ├── 04_mrr_advanced.sql          ← MoM growth + 3M rolling avg + YTD + acceleration
│   ├── 05_subcategory_pareto.sql    ← Sub-category Pareto + profitability flag
│   ├── 06_regional_performance.sql  ← Regional RANK + profit per order + YoY
│   ├── 07_discount_impact.sql       ← Discount tier analysis + loss rate
│   └── 08_customer_value.sql        ← Customer NTILE deciles + value vs profit tiers
│
├── powerbi/
│   ├── measures.md                  ← DAX measures: time intelligence, rolling avg, rankings
│   └── data_model.md                ← View schemas, Power Query, custom visuals
│
├── assets/
│   ├── Home.png
│   ├── MRR.png
│   ├── Churn.png
│   └── Segments.png
│
├── superstore-financial-kpis.pbix   ← Power BI file (open in Power BI Desktop)
└── README.md
```

---

## 🚀 How to Reproduce

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)
2. Upload the CSV to BigQuery (dataset name: `superstore`, table name: `orders`)
3. Run the SQL queries in order (01 → 08) to create the views and analytical queries
4. Open the `.pbix` file in Power BI Desktop — the data will load automatically if connected to the same BigQuery project
5. Add the DAX measures from [`powerbi/measures.md`](./powerbi/measures.md) to enhance the model

---

## 👩‍💻 About

Built by **Ana Paula Borges** · [LinkedIn](https://linkedin.com/in/ana-paula-d-araújo-borges) · [GitHub](https://github.com/ANAPBORGES)

*Senior Data Analyst & Team Leader with 10+ years in BI, DataViz, and Marketing Analytics.*
