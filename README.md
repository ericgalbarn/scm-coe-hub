# Global SCM CoE Performance & Inventory Optimization Hub

**A production-grade supply chain analytics platform for a global building materials manufacturer.**

![Status: Complete](https://img.shields.io/badge/status-complete-green)
![BigQuery](https://img.shields.io/badge/bigquery-385K%20rows-green)
![Looker Studio](https://img.shields.io/badge/dashboard-looker%20studio-blue)
![Sprints](https://img.shields.io/badge/sprints-6%2F10-blue)

---

## 🎯 The Situation

A global building materials and home fixtures company operates across **15 plants in 3 regions** (Americas, Europe, APAC). Regional supply chain teams rely on fragmented SAP reports, manual Excel tracking, and inconsistent KPI definitions. There is **no single source of truth** for executive S&OP decision-making.

**The SCM Center of Excellence team needs a standardized global platform** that:
- Visualizes supply chain performance across all regions
- Provides data-driven inventory optimization proposals
- Standardizes KPIs (OTIF, Inventory Turns, Days of Supply, Backorder Rate)
- Enables regional planners to make faster, data-backed decisions

---

## 🎬 The Task

**Design and build an enterprise-ready analytics solution** that:

1. Models SAP ERP transactional data into a centralized Google BigQuery data warehouse
2. Delivers interactive BI dashboards for 4 stakeholder groups (Executive, Americas, Europe, S&OP)
3. Automates safety stock calculations, 26-week inventory projections, and inter-company reallocation proposals
4. Establishes a standard operating procedure (SOP) for monthly S&OP alignment across regions

---

## ⚡ The Action

### Phase 1: Foundation (Sprints 1-2)
- Designed a **Star Schema data model** with 3 fact tables (`sales`, `purchase`, `inventory`) and 2 dimension tables (`material`, `plant`) in BigQuery
- Mapped SAP standard tables (VBAK, EKKO, MARD, MARA, T001W) directly to analytics-ready schema with partitioning and clustering for query performance
- Generated **385,907 rows of realistic synthetic data** using Python, simulating real SAP transactional patterns including seasonal demand, supplier delays, and regional variations

### Phase 2: Analytics Engineering (Sprints 3-6)
- Built **13 SQL analytics views** using CTEs, Window Functions, and statistical aggregations
- Implemented **Two-Factor Safety Stock Model** (SS = Z × √(L×σd² + d²×σL²)) in pure SQL for Americas inventory optimization
- Developed **Inter-Company Reallocation Matrix** with financial viability logic: approve transfers only when holding cost saved > freight cost
- Created **Forecast Accuracy tracking** comparing planned vs actual demand across regions

### Phase 3: Visualization & Insights (Sprints 3-6)
- Built **4 interactive dashboard tabs** in Looker Studio with native BigQuery integration
- Designed for distinct stakeholders: Executive VP (global KPIs), Americas Planner (safety stock + tariff), Europe Logistics (vendor delay + reallocation), S&OP Committee (capacity vs demand)
- Added **drill-down filters** (plant, category, vendor) enabling planners to self-serve answers
- Integrated **Google Sheets** for planner safety stock overrides — bridging BI tools with familiar workflows

### Phase 4: Governance (Sprints 7-8)
- Defined **SOP-SCM-COE-004**: monthly S&OP cadence covering data ingestion, planner review, reallocation execution, and executive sign-off
- Built **data reconciliation SQL scripts** to detect orphaned keys and transactional discrepancies between BigQuery and source systems
- Designed **UAT framework** with 3 test scenarios for OTIF calculation, Google Sheets ingestion, and reallocation financial integrity

---

## 📊 The Result

### Dashboard Delivered

| Tab | Audience | Key Features |
|-----|----------|--------------|
| **Executive Overview** | VP Supply Chain, COO | OTIF 88.6%, Inventory $70M, Backorder 13.5%, Global Plant Map, Regional Trends |
| **Americas Region** | Demand/Supply Planning Lead | Top 10 Risk SKUs, 26-Week Projection, Tariff Comparison (US 25% vs BR 35%), Landed Cost Breakdown |
| **Europe Region** | Fulfillment & Inventory Lead | Vendor Delivery Performance, Slow-Moving Stock Screening (>180 days), Approved Reallocation Proposals |
| **S&OP Alignment** | S&OP Committee, Schedulers | Capacity Utilization Heatmap, Demand vs Capacity by Category, Forecast Accuracy Tracking |

### 12 Actionable Insights Generated

**Executive Level:**
1. US holds 21% of global inventory ($14.7M) — concentration risk identified
2. October is a recurring "OTIF black hole" — Americas 80%, APAC 74%
3. APAC supply chain shows "roller-coaster" instability — 19-point OTIF swing in 1 month

**Americas Region:**
4. Chicago Manufacturing Plant: #1 critical facility (24.8% of stockout-risk SKUs)
5. Brazil tariff (35%) creates 10% cost disadvantage vs US — margin at risk
6. Bath Fixtures is the "problem child" category — highest cost, tariff, freight, and risk score

**Europe Region:**
7. VEND0015: systemic vendor failure — 80%+ late rate across multiple plants
8. €6.2M trapped in slow-moving stock across 3 German/Italian plants
9. Milan → Munich reallocation: $11.3K savings on a single SKU transfer

**S&OP Alignment:**
10. Bath Fixtures: only category with capacity deficit (19.5% gap)
11. 70% of manufacturing capacity is under-utilized — significant idle resources
12. July 2025 forecast: all 3 regions under-forecasted (APAC +51.4%)

---

## 🛠️ Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Data Warehouse | **Google BigQuery** | Native integration with BI tools, serverless scaling, partition pruning |
| BI / Visualization | **Looker Studio** | Native BigQuery connector, free, Google Sheets integration for planner workflows |
| ETL / Data Gen | **Python** (pandas, numpy) | Programmatic data generation with realistic SAP patterns |
| Source Data Model | **SAP ERP** | Standard tables: VBAK, VBAP, EKKO, EKPO, MARD, MARA, T001W |
| Collaboration | **Google Sheets** | Planner safety stock overrides synced to BigQuery |


---


## 📦 Project Structure

```
scm-coe-hub/
├── sql/                        # All SQL scripts
│   ├── 01_dim_region_plant.sql
│   ├── 02_dim_material.sql
│   ├── 03_fact_sales_order.sql
│   ├── 04_fact_purchase_order.sql
│   ├── 05_fact_daily_inventory.sql
│   └── 06_verify_table_creation.sql
│   ├── 07_kpi_views.sql              # OTIF, Inventory, Backorder, Turns
│   └── 08_americas_views.sql         # Safety Stock, Projection, Tariff
│   └── 09_europe_views.sql          # Vendor Delay, Slow-Moving, Reallocation
│   └── 10_sop_views.sql          # Capacity, Forecast Accuracy
├── python/                     # Data generation & ETL
│   ├── generate_data.py        # Synthetic data generator
│   ├── load_to_bigquery.py     # BigQuery loader
│   └── utils/                  # Shared utilities
├── img/                        # Architecture & formula images
├── README.md
└── requirements.txt
```

---



## 🏃 Sprint Progress


| Sprint | Week | Goal                                   | Status |
| ------ | ---- | -------------------------------------- | ------ |
| **1**  | 1    | BigQuery Schema Setup                  | ✅ Done |
| **2**  | 2    | Synthetic Data Engine                  | ✅ Done |
| **3**  | 3-4  | Tab 1 - Executive Dashboard (MVP)      | ✅ Done |
| **4**  | 5    | Tab 2 - Americas Regional View         | ✅ Done |
| **5**  | 6    | Tab 3 - Europe Regional View           | ✅ Done |
| **6**  | 7    | Tab 4 - S&OP Alignment + Google Sheets | ✅ Done |
| 7      | 8    | Automation + SOP Documentation         | ⬜      |
| 8      | 9    | Testing & UAT                          | ⬜      |
| 9      | 10   | Portfolio Packaging                    | ⬜      |



---

## 🎓 What This Demonstrates

| Skill | Evidence in Project |
|-------|---------------------|
| **S&OP Domain Knowledge** | Safety Stock modeling, OTIF calculation, Days of Supply, Inventory Turns, Capacity Planning |
| **SAP Functional Knowledge** | Direct mapping from VBAK/EKKO/MARD to analytics schema, understanding of STO (ME21N) |
| **SQL Proficiency** | 13 views with CTEs, Window Functions, statistical functions (STDDEV, CORR), conditional logic |
| **BI Tool Experience** | 4-tab Looker Studio dashboard with filters, conditional formatting, calculated fields |
| **Data Modeling** | Star Schema design, partitioning, clustering, SCD Type 1 dimensions |
| **Data Validation** | Reconciliation scripts, UAT framework, orphaned key detection |
| **Cross-Regional Collaboration** | SOP for multi-timezone S&OP cadence, Google Sheets for planner input |
| **Analytical Thinking** | 12 actionable insights from raw data, connecting multi-tab findings |
| **Agile Methodology** | 10-sprint roadmap with MVP-first approach, incremental feature delivery |

---

## 📸 Dashboard Preview

🔗 [View Live Dashboard](YOUR_LOOKER_STUDIO_LINK)

![Executive Dashboard](img/tab1_executive.png)
![Americas Dashboard](img/tab2_americas.png)
![Europe Dashboard](img/tab3_europe.png)
![S&OP Dashboard](img/tab4_sop.png)

---

*Built as a portfolio project demonstrating SCM analytics, data engineering, and business intelligence skills for a CoE Analyst role.*