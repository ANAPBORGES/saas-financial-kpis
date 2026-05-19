# SaaS Financial KPIs 💰
> End-to-end financial analysis of a retail dataset, simulating SaaS metrics — MRR, churn rate, retention and customer segments with YoY growth.

[![SQL](https://img.shields.io/badge/SQL-BigQuery-4285F4?style=flat&logo=google-cloud)](https://cloud.google.com/bigquery)
[![Dashboard](https://img.shields.io/badge/Dashboard-Power%20BI-F2C811?style=flat&logo=powerbi)](./dashboard/superstore-financial-kpis.pbix)
[![Status](https://img.shields.io/badge/Status-Complete-success?style=flat)]()

---

## 📌 Business Context

**Industry:** Retail / SaaS-inspired analytics
**Stakeholders:** Finance, Commercial, and C-level teams
**Business question:** *How does revenue evolve over time, which customer segments drive the most value, and how can we reduce churn?*

This project analyzes 4 years of sales data from the Superstore dataset (2014–2017), applying SaaS financial metrics — MRR, churn rate, retention rate, and NRR proxy — to a retail context. The goal was to build an executive dashboard that translates raw transactional data into strategic financial KPIs, enabling data-driven decisions across revenue planning, customer retention, and segment prioritization.

---

## 🎯 Objectives

- [x] Analyze monthly recurring revenue (MRR) trends and seasonality patterns
- [x] Calculate customer churn and retention rates year over year
- [x] Segment revenue and profit by customer type and region
- [x] Measure YoY growth per segment to identify expansion opportunities
- [x] Deliver a multi-page executive dashboard with navigation and actionable KPIs

---

## 🗂 Dataset

| Field | Details |
|---|---|
| **Source** | [Kaggle — Superstore Sales Dataset](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final) |
| **Size** | ~10K orders, 1 table |
| **Period** | January 2014 – December 2017 |

**Key fields used:**
- `Order Date` — used to build monthly and yearly time series
- `Sales` — base for MRR and revenue calculations
- `Profit` — used for margin and profitability analysis
- `Customer ID` — used for churn and retention cohorts
- `Segment` — Consumer, Corporate, Home Office
- `Region` — West, East, Central, South

---

## 🔧 Technical Approach

### Data Model
```
superstore.orders
    └── vw_mrr          -- monthly revenue, orders, customers and margin
    └── vw_churn        -- yearly retention and churn rates
    └── vw_segments     -- revenue and profit by segment, region and YoY growth
```

### SQL Queries

| Query | Description |
|---|---|
| [`01_mrr.sql`](./sql/01_mrr.sql) | Monthly revenue, active customers and profit margin |
| [`02_churn.sql`](./sql/02_churn.sql) | Yearly customer retention and churn rate |
| [`03_nrr_segments.sql`](./sql/03_nrr_segments.sql) | Revenue by segment and region with YoY growth |

---

## 📈 Key Findings

1. **Consistent revenue growth** — total revenue grew from $484K in 2014 to $733K in 2017, a 51% increase over 4 years
2. **Retention improving year over year** — customer retention improved from 73% (2014) to 87% (2016), reducing churn from 26% to 12%
3. **Consumer segment dominates** — Consumer accounts for ~50% of total revenue ($1.16M), nearly double Corporate ($706K)
4. **West region leads** — West generates the highest revenue ($725K), while South lags significantly behind other regions
5. **Profit margin volatility** — avg margin of 12.5% with monthly spikes and dips, suggesting pricing or discount inconsistencies worth investigating

---

## 📊 Dashboard

**Tool:** Power BI Desktop
**File:** [Download .pbix](./dashboard/superstore-financial-kpis.pbix)

The dashboard includes 4 pages with full navigation:

| Page | Content |
|---|---|
![Home](./assets/Home.png)
![MRR](./assets/MRR.png)
![Churn](./assets/Churn.png)
![Segments](./assets/Segments.png)

**Dashboard previews:**

![Home](./assets/dashboard_home.png)
![MRR](./assets/dashboard_mrr.png)
![Churn](./assets/dashboard_churn.png)
![Segments](./assets/dashboard_segments.png)

---

## 📁 Repository Structure

```
saas-financial-kpis/
│
├── sql/
│   ├── 01_mrr.sql
│   ├── 02_churn.sql
│   └── 03_nrr_segments.sql
│
├── dashboard/
│   └── superstore-financial-kpis.pbix
│
├── assets/
│   ├── dashboard_home.png
│   ├── dashboard_mrr.png
│   ├── dashboard_churn.png
│   └── dashboard_segments.png
│
└── README.md
```

---

## 🚀 How to Reproduce

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)
2. Upload the CSV to BigQuery (dataset name: `superstore`, table name: `orders`)
3. Run the 3 SQL queries to create the views
4. Open the `.pbix` file in Power BI Desktop — the data will load automatically if connected to the same BigQuery project

---

## 👩‍💻 About

Built by **Ana Paula Borges** · [LinkedIn](https://linkedin.com/in/ANAPBORGES) · [GitHub](https://github.com/ANAPBORGES)

*Senior Data Analyst & Team Leader with 10+ years in BI, DataViz, and Marketing Analytics.*
