# Global SCM CoE Performance & Inventory Optimization Hub

## 1. Executive Summary & Business Case

### 1.1 Project Overview
In global supply chain management, operational inefficiencies often stem from fragmented data across regional nodes, delayed visibility into purchase and sales cycles, and sub-optimal inventory policies. This portfolio project, titled the **"Global SCM CoE Performance & Inventory Optimization Hub"**, is designed as a production-grade, enterprise-ready analytical solution that bridges the gap between raw transaction data and executive S&OP (Sales and Operations Planning) decision-making.

By modeling SAP ERP transactional data into a centralized **Google BigQuery Data Warehouse**, this project establishes a single source of truth for global performance. The hub serves three primary regional clusters (Americas, Europe, and Asia-Pacific) with interactive BI dashboards, standardizing performance measurement and delivering actionable inventory optimization proposals.

```
       +---------------------------------------------+
       |   SAP ERP Core Tables (VBAK, EKKO, MARD)    |
       +---------------------------------------------+
                              |
                              v  (Fivetran / Cloud Data Fusion Pipeline)
       +---------------------------------------------+
       |       Google BigQuery Data Warehouse        |
       |  - Star Schema Model (Fact & Dim Tables)    |
       |  - Advanced SQL SCM KPI Analytics Views     |
       +---------------------------------------------+
                              |
          +-------------------+-------------------+
          |                                       |
          v                                       v
+-----------------------------+         +-----------------------------+
|    Power BI Dashboard       |         |  Shared Services Tools      |
|  - Exec Overview            |         |  - Americas Safety Stock    |
|  - Americas Waterfall       |         |  - Europe Reallocation      |
|  - Europe PO/SO Delay       |         |  - Google Sheets Overrides  |
+-----------------------------+         +-----------------------------+
```

### 1.2 Core Objectives
- **Global SCM Data Visibility:** Eliminate data silos by mapping and modeling core SCM transactions from SAP to an optimized Star Schema in Google BigQuery.
- **SCM KPI Standardization:** Automate key metrics calculations including On-Time In-Full (OTIF%), Days of Supply (DOS), and Inventory Turns.
- **Americas Regional Support:** Deliver a 26-week inventory projection and an advanced Safety Stock target setting matrix that accounts for lead time and demand variability.
- **Europe Regional Support:** Build a PO/SO delay-tracking framework and an Inter-company Inventory Reallocation matrix that optimizes freight costs versus holding costs for slow-moving stock (>180 days).
- **Process Standardization:** Define a Standard Operating Procedure (SOP-SCM-COE-004) to govern regional S&OP alignment and data-driven inventory reallocation.

---

## 2. Technical Architecture & Data Pipeline Map

To demonstrate practical enterprise experience, this project models data originating from standard **SAP ERP (Enterprise Resource Planning)** tables. These tables are replicated or exported to **Google BigQuery**, where modern SQL transformation (CTEs, Window Functions, Analytics Functions) organizes them into a highly efficient **Star Schema**.

```
+--------------------------------------------+
|            SAP SOURCE TABLES               |
|                                            |
|  [VBAK / VBAP]       [EKKO / EKPO]         |
|  Sales Headers/Items  Purchase Headers/Items|
|         \                  /               |
|          \                /                |
|           v              v                 |
|       [MARD]          [MARA / MARC]        |
|     Storage Stock     Material Master      |
+--------------------------------------------+
                      |
                      |  (Extraction & Transformation Pipeline)
                      v
+--------------------------------------------+
|          BIGQUERY DATA WAREHOUSE           |
|                                            |
|   Fact Tables:                             |
|   - `fact_sales_order`                     |
|   - `fact_purchase_order`                  |
|   - `fact_daily_inventory`                 |
|                                            |
|   Dimension Tables:                        |
|   - `dim_material`                         |
|   - `dim_region_plant`                     |
+--------------------------------------------+
```

### 2.1 SAP to BigQuery Mapping Strategy
The warehouse is built upon five primary tables, directly mapped from standard SAP modules:

1. **`fact_sales_order`** *(Derived from SAP tables `VBAK` - Sales Document Header, `VBAP` - Sales Document Item, and `VBEP` - Sales Document Schedule Line)*
   - Tracks customer sales orders, requested delivery dates, actual delivery dates, ordered quantities, and delivered quantities.
2. **`fact_purchase_order`** *(Derived from SAP tables `EKKO` - Purchasing Document Header, `EKPO` - Purchasing Document Item, and `EKET` - Purchase Order Delivery Schedule)*
   - Tracks procurement cycles from vendors, including purchase order placement, delivery dates, and goods receipt quantities.
3. **`fact_daily_inventory`** *(Derived from SAP tables `MARD` - Storage Location Stock, snapshot daily and combined with `MSEG` - Document Segment Material for historic snapshots)*
   - Provides a daily end-of-day stock quantity and inventory value (standard cost) for each material-plant-storage location combination.
4. **`dim_material`** *(Derived from SAP tables `MARA` - General Material Data and `MARC` - Plant Data for Material)*
   - Stores material master attributes: SKU, Category, UoM (Unit of Measure), Standard Cost, Safety Stock parameters, and Lead Times.
5. **`dim_region_plant`** *(Derived from SAP tables `T001W` - Plants/Branches and `T001` - Company Codes)*
   - Defines organizational hierarchies, matching physical plants to regions (Americas, Europe, APAC) and legal entities.

---

## 3. Data Warehouse Schema Definition (BigQuery Star Schema)

Below is the physical and logical schema design of the BigQuery database. All tables enforce data integrity and optimization patterns (e.g., partitioning by date to reduce query scan costs).

### 3.1 Fact Tables

#### Table: `fact_sales_order`
*Partitioned by: `create_date` (Daily)*  
*Clustered by: `region_id`, `plant_id`*

| Column Name | BigQuery Type | Key Type | SAP Source Field | Description |
| :--- | :--- | :--- | :--- | :--- |
| `sales_order_key` | STRING | PK | `VBAK.VBELN` + `VBAP.POSNR` | Unique composite identifier for Sales Order Line |
| `sales_order_id` | STRING | FK | `VBAK.VBELN` | Sales Document Number |
| `sales_order_line` | INT64 | - | `VBAP.POSNR` | Sales Document Line Item Number |
| `create_date` | DATE | - | `VBAK.ERDAT` | Date the sales order record was created |
| `requested_delivery_date` | DATE | - | `VBAK.VDATU` | Customer's requested delivery date |
| `actual_delivery_date` | DATE | - | `LIPS.WADAT_IST` | Actual goods issue/delivery date from outbound delivery |
| `material_id` | STRING | FK | `VBAP.MATNR` | Material/SKU number |
| `plant_id` | STRING | FK | `VBAP.WERKS` | Dispatching plant |
| `region_id` | STRING | FK | Custom / Map Table | Target operating region (AMER, EU, APAC) |
| `ordered_qty` | NUMERIC | - | `VBAP.KWMENG` | Quantity ordered by the customer (in base UoM) |
| `delivered_qty` | NUMERIC | - | `LIPS.LFIMG` | Quantity physically delivered to the customer |
| `net_price` | NUMERIC | - | `VBAP.NETPR` | Net value of the line item in local currency |
| `currency` | STRING | - | `VBAK.WAERK` | Document Currency (e.g., USD, EUR) |
| `order_status` | STRING | - | `VBUK.GBSTK` | Header overall status (Open, Shipped, Cancelled) |

#### Table: `fact_purchase_order`
*Partitioned by: `po_create_date` (Daily)*  
*Clustered by: `plant_id`, `vendor_id`*

| Column Name | BigQuery Type | Key Type | SAP Source Field | Description |
| :--- | :--- | :--- | :--- | :--- |
| `po_line_key` | STRING | PK | `EKKO.EBELN` + `EKPO.EBELP` | Unique composite identifier for Purchase Order Line |
| `po_id` | STRING | FK | `EKKO.EBELN` | Purchase Order Document Number |
| `po_line` | INT64 | - | `EKPO.EBELP` | Purchase Order Line Item Number |
| `po_create_date` | DATE | - | `EKKO.AEDAT` | Purchase Order creation date |
| `scheduled_delivery_date` | DATE | - | `EKET.EINDT` | Delivery date committed by the vendor |
| `actual_goods_receipt_date` | DATE | - | `EKBE.BUDAT` | Actual date goods were received in the warehouse |
| `material_id` | STRING | FK | `EKPO.MATNR` | Material/SKU number |
| `plant_id` | STRING | FK | `EKPO.WERKS` | Receiving plant |
| `vendor_id` | STRING | - | `EKKO.LIFNR` | Vendor/Supplier identifier |
| `ordered_qty` | NUMERIC | - | `EKPO.MENGE` | Quantity ordered from vendor |
| `received_qty` | NUMERIC | - | `EKBE.MENGE` | Quantity received (from Goods Receipt logs) |
| `unit_cost` | NUMERIC | - | `EKPO.NETPR` | Purchase unit cost |
| `currency` | STRING | - | `EKKO.WAERS` | Purchasing Currency |
| `po_status` | STRING | - | `EKKO.STATU` | Line status (Open, Partial, Fully Received) |

#### Table: `fact_daily_inventory`
*Partitioned by: `snapshot_date` (Daily)*  
*Clustered by: `plant_id`, `material_id`*

| Column Name | BigQuery Type | Key Type | SAP Source Field | Description |
| :--- | :--- | :--- | :--- | :--- |
| `inventory_key` | STRING | PK | Composite Key | Generated Hash of Date + Plant + Storage Loc + SKU |
| `snapshot_date` | DATE | - | Historical Record | Date of the daily inventory snapshot |
| `material_id` | STRING | FK | `MARD.MATNR` | Material Number |
| `plant_id` | STRING | FK | `MARD.WERKS` | Plant identifier |
| `storage_location` | STRING | - | `MARD.LGORT` | Storage Location within the plant |
| `stock_qty_on_hand` | NUMERIC | - | `MARD.LABST` | Unrestricted stock quantity on hand at EOD |
| `blocked_stock_qty` | NUMERIC | - | `MARD.SPEME` | Blocked stock (non-allocatable/quality hold) |
| `standard_unit_cost` | NUMERIC | - | `MBEW.VERPR` or `MBEW.STPRS` | Unit standard or moving average cost |
| `inventory_value_usd` | NUMERIC | - | Derived calculation | `stock_qty_on_hand` * `standard_unit_cost` (converted) |

### 3.2 Dimension Tables

#### Table: `dim_material`
*Clustered by: `material_category`*

| Column Name | BigQuery Type | Key Type | SAP Source Field | Description |
| :--- | :--- | :--- | :--- | :--- |
| `material_id` | STRING | PK | `MARA.MATNR` | Material Number (e.g., SKU Code) |
| `material_name` | STRING | - | `MAKT.MAKTX` | Detailed material description (text) |
| `material_category` | STRING | - | `MARA.MATKL` | Material Group/Category (e.g., Faucets, Ceramics) |
| `uom` | STRING | - | `MARA.MEINS` | Base Unit of Measure (e.g., PC, BOX, KG) |
| `abc_classification` | STRING | - | `MARC.MAABC` | ABC rating based on annual consumption value (A/B/C) |
| `standard_lead_time_days` | INT64 | - | `MARC.PLIFZ` | Planned Delivery Time in days (Supplier Lead Time) |
| `unit_weight` | NUMERIC | - | `MARA.NTGEW` | Net weight of the material unit |
| `weight_uom` | STRING | - | `MARA.GEWEI` | Weight unit of measure |

#### Table: `dim_region_plant`

| Column Name | BigQuery Type | Key Type | SAP Source Field | Description |
| :--- | :--- | :--- | :--- | :--- |
| `plant_id` | STRING | PK | `T001W.WERKS` | Plant Code (e.g., US01, DE02, VN01) |
| `plant_name` | STRING | - | `T001W.NAME1` | Name of the manufacturing/distribution plant |
| `region` | STRING | - | Custom / Mapping | Global Region assignment (Americas, Europe, APAC) |
| `country` | STRING | - | `T001W.LAND1` | Country of location |
| `city` | STRING | - | `T001W.ORT01` | City of location |
| `is_manufacturing_flag` | BOOLEAN | - | Custom / Map Table | `TRUE` if manufacturing site; `FALSE` if DC/warehouse |

---

## 4. Analytical Models & Optimization Formulas

To operate as a Staff-level SCM CoE Analyst, the hub does not just display raw data. It runs statistical and operational models directly inside SQL views and analytical components.

### 4.1 Americas Regional Model: Safety Stock Target Setting
The Americas region faces volatile supplier lead times and highly variable customer demand. To prevent stockouts without over-inflating inventory carrying costs, we implement the **Advanced Two-Factor Safety Stock Model** which accounts for both **Demand Uncertainty** and **Lead Time Uncertainty** independently.

#### The Mathematical Model:

The safety stock target (SS) is computed using the following standard SCM formula:

![Americas Safety Stock Formula](img/Americas%20Regional%20Model:%20Safety%20Stock%20Formula%20.png)

Where:
- **SS**: Safety Stock.
- **Z**: Service factor (the number of standard deviations needed for your target cycle service level).
- **L**: Average lead time (the mean time it takes to replenish inventory).
- **&sigma;<sub>d</sub>** (Sigma_d): Standard deviation of demand (measures daily or weekly sales volatility).
- **D**: Average demand (the mean sales volume per period).
- **&sigma;<sub>L</sub>** (Sigma_L): Standard deviation of lead time (measures supply chain delays, such as customs or transit bottlenecks).

#### SQL Transformation Logic (Staged as a BigQuery View):
1. **Daily Demand Aggregator:** Calculate average daily demand (D) and demand standard deviation (Sigma_d) over a rolling 180-day window.
2. **Lead Time Aggregator:** Compare `po_create_date` and `actual_goods_receipt_date` on `fact_purchase_order` to compute average lead time (L) and lead time volatility (Sigma_L) per vendor-SKU combination.
3. **Safety Stock Computations:** Combine aggregated metrics into the formula using statistical functions.

---

### 4.2 Europe Regional Model: Inter-Company Inventory Reallocation Matrix
European distribution channels often experience localized excess stock in one hub while simultaneously experiencing backorders in another. Rather than purchasing new inventory from vendors (which takes weeks and incurs customs/tariffs), we deploy an **Inter-Company Reallocation Matrix**.

This matrix identifies **Slow-Moving Stock (>180 Days of Supply)** in a "Surplus Plant" and matches it against immediate **Backorders or High Stockout Risks** in a "Deficit Plant", prioritizing transactions where the cost of reallocation is strictly lower than purchasing and carrying costs.

#### Decision Logic Flow:
```
[Identify Excess Stock (DOS > 180)] ---> [Identify Deficit Plants (DOS < Safety Stock)]
                                              |
                                              v
                              +---------------------------------+
                              | Calculate Reallocation Viability|
                              +---------------------------------+
                                              |
                     +------------------------+------------------------+
                     |                                                 |
                     v                                                 v
         Reallocation Savings > 0                          Reallocation Savings <= 0
    (Freight Cost < Holding Cost Saved)               (Freight Cost >= Holding Cost Saved)
                     |                                                 |
                     v                                                 v
         [PROPOSE REALLOCATION]                              [REJECT / HOLD STOCK]
```

#### The Financial Viability Equation:

The optimization and reallocation logic are calculated using the following financial equations:

![Financial Viability Equation](img/Financial%20Viability%20Equation.png)

Where:
- **C** (SKU Standard Cost): The base manufacturing or purchase cost per unit. [Unit: $ / unit]
- **I** (Annual Carrying Cost Rate): The annual holding cost percentage, typically between 0.18 and 0.25 (18% - 25%). [Unit: % / year]
- **M** (Holding Duration): The number of months the surplus stock is projected to sit idle if *not* reallocated. [Unit: Months]
- **Q_realloc** (Transfer Quantity): The total number of units being moved. It is strictly capped by whichever is smaller: the available excess at the source or the net requirement at the destination. [Unit: Units]
- **F** (Transit Freight Cost): The variable, per-unit logistics and transportation rate between the two facilities. [Unit: $ / unit]
- **S** (Fixed Handling Surcharge): The flat administrative, picking, and repackaging fee applied per transfer order regardless of size. [Unit: $ / order]

A reallocation is strictly proposed when:
```math
\text{Reallocation Savings} > 0
```

---

## 5. Dashboard Specification & Layout Design

The visual layer is designed across four interactive dashboard tabs, serving distinct stakeholder audiences from Global Executive VP to regional inventory planners.

```
+-----------------------------------------------------------------------------+
|  [TAB 1: GLOBAL SCM EXEC] | TAB 2: AMER REGION | TAB 3: EU REGION | TAB 4: S&OP   |
+-----------------------------------------------------------------------------+
|                                                                             |
|  [ Global Map of Plants ]    [ OTIF %: 94.2% ]    [ Inv Value: $12.4M ]     |
|                              (Target: 95.0%)      (Target: < $11.0M)        |
|                                                                             |
|  [---------------------- SCM Performance Trends -------------------------] |
|  [                                                                       ]  |
|  +-------------------------------------------------------------------------+
```

### 5.1 Tab 1: Global SCM Executive Overview
* **Target Audience:** VP of Global Supply Chain, Chief Operating Officer (COO).
* **Key Performance Indicators (KPIs):**
  - **OTIF % (On-Time In-Full):** Percentage of sales orders delivered by the requested date in full.
  - **Total Inventory Value ($):** Current aggregated standard cost of inventory across all plants.
  - **Backorder Rate (%):** Unfilled sales order lines past requested delivery date as a percentage of total open orders.
  - **Inventory Turns:** Cost of Goods Sold (COGS) / Average Inventory Value.
* **Visual Elements:**
  - **Global Geo Map:** Color-coded circles representing plant locations; color denotes OTIF % (Red <90%, Yellow 90-95%, Green >95%) and size denotes current Inventory Value.
  - **Monthly SCM Performance Line Chart:** Dual-axis chart tracking historical OTIF% (line) and Inventory Turns (line) against target thresholds over a rolling 12 months.

### 5.2 Tab 2: Americas Regional View
* **Target Audience:** Americas Demand/Supply Planning Lead.
* **Key Functional Capabilities:**
  - **Tariff Impact Analyzer:** Financial model isolating the impact of changes in import tariffs on landed cost.
  - **26-Week Forward Inventory Projection:** Area chart projecting inventory levels (On-Hand + Firm PO Receipts - Forecasted Demand) against Minimum, Safety, and Maximum thresholds.
* **Visual Elements:**
  - **Tariff Financial Waterfall:** Waterfall chart illustrating how standard material cost, base freight, insurance, and import tariffs accumulate to form the Total Landed Cost.
  - **26-Week Inventory Projection Chart:** Stacked line/area chart tracking weekly projected stock levels, alerting planners with highlighted red markers when projected stock dips below safety limits.
  - **Safety Stock Overrides Grid:** Table displaying calculated vs. recommended (planners' override) Safety Stock targets, sourced from Google Sheets.

### 5.3 Tab 3: Europe Regional View
* **Target Audience:** European Fulfillment & Inventory Logistics Lead.
* **Key Functional Capabilities:**
  - **PO/SO Delivery Latency Heatmap:** Diagnostics tool pinpointing vendor and transport corridor bottlenecks.
  - **Excess and Slow-Moving Stock Screening:** Identifying items with zero consumption or extreme aging (>180 days).
  - **Inter-Company Reallocation Scatter Plot:** Reallocation suggestions mapping freight cost vs. holding cost trade-offs.
* **Visual Elements:**
  - **Vendor Delivery Delay Matrix:** Grid displaying average transit delays (Actual GR Date - Scheduled Delivery Date) categorized by Vendor and receiving European Plant.
  - **Inter-Company Reallocation Planner:** A scatter plot of potential transfers. Y-axis: *Holding Cost Saved ($)*; X-axis: *Freight Cost ($)*. Bubble size: *Quantity to Reallocate*.
    - **Quadrant 1 (Top-Left): High Savings, Low Freight Cost.** These are flagged as "Immediate Auto-Approve Reallocations".

### 5.4 Tab 4: S&OP Alignment Matrix
* **Target Audience:** Regional S&OP Committee, Master Production Schedulers.
* **Key Functional Capabilities:**
  - **Demand vs. Capacity Balancing:** Direct comparison of unconstrained commercial forecast against raw manufacturing capacity.
* **Visual Elements:**
  - **Monthly Variance Chart:** Grouped bar chart comparing Forecast Demand (Units) and Available Production Capacity (Units) per product category.
  - **Capacity Utilization Heatmap:** Highlighting resource constraints (Red: >100% overload, Green: 70-95% optimal, Blue: <70% under-utilized).

---

## 6. Business Process & Standard Operating Procedure (SOP-SCM-COE-004)

To ensure analytical insights translate directly to execution, we establish a standardized governance model. The **SOP-SCM-COE-004** outlines the exact monthly cadence for utilizing the hub during the S&OP cycle.

```
       [WEEK 1: DATA INGESTION]
       BigQuery automatically pulls the previous month's SAP records.
                  |
                  v
     [WEEK 2: PLANNERS OVERRIDE]
     Regional planners review Safety Stocks and enter manual overrides via Google Sheets.
                  |
                  v
       [WEEK 3: REALLOCATION RUN]
       Logistics teams run the Europe Reallocation Matrix to balance stock.
                  |
                  v
    [WEEK 4: EXECUTIVE REVIEW (S&OP)]
    Executive VP uses Tab 1 & Tab 4 of the Dashboard to lock in next month's targets.
```

### 6.1 Process Cadence Timeline
1. **Week 1: Data Ingestion & Auto-reconciliation**
   - BigQuery automatically ingests previous month's SAP database logs.
   - Run automated SQL reconciliation checks to ensure zero data discrepancies between BigQuery and SAP.
2. **Week 2: Regional Demand Planning & Overrides Review**
   - Regional supply planners log onto the interactive Dashboard (Tab 2 & Tab 3).
   - If statistical Safety Stocks calculated in BigQuery are deemed too high/low due to upcoming promo cycles, planners enter manual overrides in the designated Google Sheets configuration tool.
3. **Week 3: Europe Reallocation Review & Procurement Cutoff**
   - European Inventory Lead extracts active suggestions from the **Inter-Company Reallocation Tool**.
   - Planners execute inter-company stock transfers in SAP (using Transaction Code `ME21N` for Stock Transport Order) based on proposed matrix matches.
4. **Week 4: Executive S&OP Sign-off Meeting**
   - CoE Lead presents executive overview (Tab 1 and Tab 4) to SCM Director and Regional Leads.
   - Lock inventory targets and production capacity caps for the upcoming rolling 3-month window.

---

## 7. Quality Assurance, Data Validation & UAT Plan

A database-driven dashboard is only as valuable as the accuracy of its underlying data. This section defines the testing framework to ensure robust data alignment.

### 7.1 User Acceptance Testing (UAT) Framework
Before deploying the dashboard to global regional planners, a structured UAT must be executed in a mock sandbox environment.

| Test Scenario ID | Test Case Objective | Target Validation Criteria | Responsible Party |
| :--- | :--- | :--- | :--- |
| **UAT-SCM-001** | Validate BigQuery OTIF% Calculation | Compare OTIF% calculated in SQL against manual SAP export for Plant US01 over 100 sales orders. Must match within 0.0%. | Global SCM CoE Lead |
| **UAT-SCM-002** | Google Sheets Override Ingestion | Update a Safety Stock target in Google Sheets; verify that BigQuery view ingests the update and overrides the statistical model within 15 mins. | Americas Inventory Planner |
| **UAT-SCM-003** | Europe Reallocation Financial Integrity | Verify that any reallocation recommendation with `Reallocation Savings <= 0` is strictly suppressed from Tab 3. | European Logistics Lead |

### 7.2 Data Audit & Reconciliation SQL Scripts
To prevent "garbage in, garbage out", the following automated data validation query runs daily to check for orphaned keys or transactional discrepancies.

```sql
-- SCM Data Reconciliation Script: Checks for orphaned transactions and mismatches
SELECT 
    'Orphaned Sales Order Lines in Warehouse' AS audit_metric,
    COUNT(DISTINCT so.sales_order_key) AS discrepancy_count
FROM `your_project.scm_analytics.fact_sales_order` so
LEFT JOIN `your_project.scm_analytics.dim_material` m ON so.material_id = m.material_id
WHERE m.material_id IS NULL

UNION ALL

SELECT 
    'Purchase Orders with Missing Plant Dimensions' AS audit_metric,
    COUNT(DISTINCT po.po_line_key) AS discrepancy_count
FROM `your_project.scm_analytics.fact_purchase_order` po
LEFT JOIN `your_project.scm_analytics.dim_region_plant` p ON po.plant_id = p.plant_id
WHERE p.plant_id IS NULL;
```

---

## 8. Implementation Roadmap (Step-by-Step)

The project will be built progressively in Cursor, ensuring a logical developer feedback loop:

- [ ] **Step 1: Database Setup & DDL Schema Generation**
  - Create the DDL SQL scripts to construct `fact_sales_order`, `fact_purchase_order`, `fact_daily_inventory`, `dim_material`, and `dim_region_plant` tables in BigQuery.
- [ ] **Step 2: Synthetic Data Engine**
  - Implement a Python-based synthetic data generator to populate the tables with realistic SCM transactional data, matching standard SAP distribution patterns (including delays, tariff fluctuations, and seasonal demand).
- [ ] **Step 3: Core Analytical Views Development**
  - Write SQL Views for:
    - SCM KPIs (OTIF%, Days of Supply, Inventory Turns).
    - Advanced Two-Factor Safety Stock Model (Americas).
    - Europe Inventory Reallocation Matrix.
- [ ] **Step 4: SOP Document Formulation**
  - Finalize the Standard Operating Procedure markdown script (`SOP-SCM-COE-004.md`) containing step-by-step guides for planners.
- [ ] **Step 5: Interactive BI Mockups**
  - Generate clean CSV datasets to import into Power BI / Looker Studio for dashboard realization.
- [ ] **Step 6: UAT & Data Validation Verification**
  - Create the UAT playbook and complete data reconciliation testing to seal 100% alignment with LIXIL's technical standards.
