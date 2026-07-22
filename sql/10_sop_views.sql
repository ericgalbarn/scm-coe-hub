-- ============================================
-- S&OP ALIGNMENT ANALYTICS - Sprint 6
-- Views: Capacity vs Demand, Monthly Variance
-- ============================================

-- -------------------------------------------
-- 6.1 Demand vs Capacity by Category
-- Question: Which categories are overloaded or under-utilized?
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_capacity_demand` AS
WITH forecast_demand AS (
    SELECT 
        DATE_TRUNC(so.create_date, MONTH) AS order_month,
        m.material_category,
        SUM(so.ordered_qty) AS forecast_demand_units
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_material` m ON so.material_id = m.material_id
    WHERE so.create_date >= '2025-01-01'
    GROUP BY order_month, m.material_category
),
manufacturing_capacity AS (
    SELECT 
        p.plant_name,
        m.material_category,
        -- Synthetic capacity: based on manufacturing plant output
        CASE 
            WHEN m.material_category = 'FAUCETS' THEN 1500
            WHEN m.material_category = 'CERAMICS' THEN 800
            WHEN m.material_category = 'PIPES_FITTINGS' THEN 2000
            WHEN m.material_category = 'VALVES' THEN 1200
            WHEN m.material_category = 'BATH_FIXTURES' THEN 500
            ELSE 1000
        END AS monthly_capacity_units
    FROM `scm-coe-hub.scm_analytics.dim_region_plant` p
    CROSS JOIN (
        SELECT DISTINCT material_category FROM `scm-coe-hub.scm_analytics.dim_material`
    ) m
    WHERE p.is_manufacturing_flag = TRUE
)
SELECT 
    f.order_month,
    f.material_category,
    f.forecast_demand_units,
    SUM(c.monthly_capacity_units) AS total_capacity_units,
    ROUND((f.forecast_demand_units / NULLIF(SUM(c.monthly_capacity_units), 0)) * 100, 1) AS utilization_pct,
    CASE 
        WHEN f.forecast_demand_units > SUM(c.monthly_capacity_units) * 0.95 THEN 'Overloaded (>95%)'
        WHEN f.forecast_demand_units BETWEEN SUM(c.monthly_capacity_units) * 0.70 AND SUM(c.monthly_capacity_units) * 0.95 THEN 'Optimal (70-95%)'
        ELSE 'Under-utilized (<70%)'
    END AS capacity_status
FROM forecast_demand f
JOIN manufacturing_capacity c ON f.material_category = c.material_category
GROUP BY f.order_month, f.material_category, f.forecast_demand_units;

-- -------------------------------------------
-- 6.2 Monthly S&OP Variance (Forecast vs Actual)
-- Question: How accurate was our forecast?
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_sop_variance` AS
WITH forecast AS (
    SELECT 
        DATE_TRUNC(so.requested_delivery_date, MONTH) AS delivery_month,
        p.region,
        SUM(so.ordered_qty) AS forecast_qty
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON so.plant_id = p.plant_id
    WHERE so.requested_delivery_date >= '2025-01-01'
    GROUP BY delivery_month, p.region
),
actual AS (
    SELECT 
        DATE_TRUNC(so.actual_delivery_date, MONTH) AS delivery_month,
        p.region,
        SUM(so.delivered_qty) AS actual_qty
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON so.plant_id = p.plant_id
    WHERE so.actual_delivery_date >= '2025-01-01'
    GROUP BY delivery_month, p.region
)
SELECT 
    f.delivery_month,
    f.region,
    f.forecast_qty,
    COALESCE(a.actual_qty, 0) AS actual_qty,
    COALESCE(a.actual_qty, 0) - f.forecast_qty AS variance_qty,
    ROUND((COALESCE(a.actual_qty, 0) - f.forecast_qty) / NULLIF(f.forecast_qty, 0) * 100, 1) AS variance_pct
FROM forecast f
LEFT JOIN actual a ON f.delivery_month = a.delivery_month AND f.region = a.region;

-- -------------------------------------------
-- 6.3 Capacity Utilization by Plant
-- Question: Which manufacturing plants are overloaded?
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_capacity_utilization` AS
WITH plant_demand AS (
    SELECT 
        DATE_TRUNC(so.create_date, MONTH) AS order_month,
        so.plant_id,
        p.plant_name,
        p.region,
        SUM(so.ordered_qty) AS total_demand_units
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON so.plant_id = p.plant_id
    WHERE so.create_date >= '2025-01-01'
      AND p.is_manufacturing_flag = TRUE
    GROUP BY order_month, so.plant_id, p.plant_name, p.region
)
SELECT 
    pd.order_month,
    pd.plant_id,
    pd.plant_name,
    pd.region,
    pd.total_demand_units,
    CASE 
        WHEN pd.region = 'Americas' THEN 2500
        WHEN pd.region = 'Europe' THEN 2000
        WHEN pd.region = 'APAC' THEN 3000
        ELSE 1500
    END AS plant_capacity,
    ROUND((pd.total_demand_units / CASE 
        WHEN pd.region = 'Americas' THEN 2500
        WHEN pd.region = 'Europe' THEN 2000
        WHEN pd.region = 'APAC' THEN 3000
        ELSE 1500
    END) * 100, 1) AS utilization_pct,
    CASE 
        WHEN pd.total_demand_units > CASE 
            WHEN pd.region = 'Americas' THEN 2500
            WHEN pd.region = 'Europe' THEN 2000
            WHEN pd.region = 'APAC' THEN 3000
            ELSE 1500
        END THEN 'Overloaded'
        ELSE 'Within Capacity'
    END AS status
FROM plant_demand pd;