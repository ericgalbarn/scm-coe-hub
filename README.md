# Global SCM CoE Performance & Inventory Optimization Hub

**Production-grade analytical solution bridging SAP ERP transactional data with executive S&OP decision-making.**

Status: In Progress
Sprint: 2
BigQuery

---

## 📋 Project Overview

Centralized **Google BigQuery Data Warehouse** serving three regional clusters (Americas, Europe, APAC) with:

- Standardized SCM KPI dashboards (OTIF%, Days of Supply, Inventory Turns)
- Americas: 26-week inventory projection & safety stock optimization
- Europe: PO/SO delay tracking & inter-company reallocation matrix
- S&OP governance via SOP-SCM-COE-004



### Architecture (High-Level)

```
SAP ERP (VBAK, EKKO, MARD) → BigQuery Star Schema → Looker Studio Dashboards
```

---



## 🗂️ Tech Stack


| Layer              | Technology              |
| ------------------ | ----------------------- |
| Data Warehouse     | Google BigQuery         |
| BI / Visualization | Looker Studio           |
| ETL / Data Gen     | Python (pandas, numpy)  |
| Source Data Model  | SAP ERP Standard Tables |


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
| 4      | 5    | Tab 2 - Americas Regional View         | ⬜      |
| 5      | 6    | Tab 3 - Europe Regional View           | ⬜      |
| 6      | 7    | Tab 4 - S&OP Alignment + Google Sheets | ⬜      |
| 7      | 8    | Automation + SOP Documentation         | ⬜      |
| 8      | 9    | Testing & UAT                          | ⬜      |
| 9      | 10   | Portfolio Packaging                    | ⬜      |


---



## 📊 Data Model (Star Schema)



### Fact Tables


| Table                  | Partition                | Source SAP Tables |
| ---------------------- | ------------------------ | ----------------- |
| `fact_sales_order`     | `create_date` (daily)    | VBAK, VBAP, VBEP  |
| `fact_purchase_order`  | `po_create_date` (daily) | EKKO, EKPO, EKET  |
| `fact_daily_inventory` | `snapshot_date` (daily)  | MARD, MSEG        |




### Dimension Tables


| Table              | Clustered By        | Source SAP Tables |
| ------------------ | ------------------- | ----------------- |
| `dim_material`     | `material_category` | MARA, MARC        |
| `dim_region_plant` | `region, country`   | T001W, T001       |




### Analytics Views (Sprint 3)


| View                | Purpose                          |
| ------------------- | -------------------------------- |
| `v_otif_summary`    | OTIF% by region, plant, month    |
| `v_inventory_value` | Current inventory value by plant |
| `v_backorder_rate`  | Backorder rate by region, month  |
| `v_inventory_turns` | Annualized inventory turns       |
| `v_monthly_trend`   | Combined monthly KPI trends      |


---



## 📸 Dashboard Preview (Sprint 3)

**Tab 1 - Executive Overview:** OTIF%, Inventory Value, Backorder Rate, Inventory Turns with global plant map and regional trend analysis.

🔗 [View Dashboard](https://datastudio.google.com/reporting/2a2f993e-fe61-44c1-9e3a-cf3774d49826)

---



## 🔍 Key Insights (from current data)

- **OTIF (88.59% vs 95% Target):** APAC & Europe miss target in peak months; vendor lead time review needed for CN01, VN01
- **Inventory Value ($70.0M):** Above target; US03 (Dallas) & UK01 (London) holding excess
- **Backorder Rate (13.49%):** Americas Oct 2024 spike (21.5%) during peak season → buffer stock adjustment required
- **Inventory Turns (442.3x):** Synthetic data calibration pending; formula validated for real SAP data

