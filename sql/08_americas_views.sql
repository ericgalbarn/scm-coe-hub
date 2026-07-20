-- ============================================
-- AMERICAS REGIONAL ANALYTICS - Sprint 4
-- Views: Safety Stock, 26-Week Projection, Tariff Impact
-- ============================================

-- -------------------------------------------
-- 4.1 Safety Stock Model (Two-Factor)
-- Formula: SS = Z * SQRT(L * σd² + d² * σL²)
-- Z = 1.645 (95% service level)
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_americas_safety_stock` AS
WITH demand_stats AS (
    SELECT 
        so.material_id,
        m.material_name,
        m.material_category,
        COUNT(DISTINCT so.sales_order_key) * 1.0 / 180 AS avg_daily_demand,
        STDDEV(so.ordered_qty) AS stddev_daily_demand,
        AVG(so.ordered_qty) AS mean_order_qty
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_material` m ON so.material_id = m.material_id
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON so.plant_id = p.plant_id
    WHERE p.region = 'Americas'
      AND so.create_date >= '2025-01-01'
    GROUP BY so.material_id, m.material_name, m.material_category
),
lead_time_stats AS (
    SELECT 
        po.material_id,
        AVG(DATE_DIFF(DATE(po.actual_goods_receipt_date), DATE(po.po_create_date), DAY)) AS avg_lead_time_days,
        STDDEV(DATE_DIFF(DATE(po.actual_goods_receipt_date), DATE(po.po_create_date), DAY)) AS stddev_lead_time_days
    FROM `scm-coe-hub.scm_analytics.fact_purchase_order` po
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON po.plant_id = p.plant_id
    WHERE p.region = 'Americas'
      AND po.actual_goods_receipt_date IS NOT NULL
    GROUP BY po.material_id
)
SELECT 
    d.material_id,
    d.material_name,
    d.material_category,
    d.avg_daily_demand,
    d.stddev_daily_demand,
    COALESCE(l.avg_lead_time_days, 14) AS avg_lead_time_days,
    COALESCE(l.stddev_lead_time_days, 3) AS stddev_lead_time_days,
    1.645 AS z_score_95,
    ROUND(
        1.645 * SQRT(
            COALESCE(l.avg_lead_time_days, 14) * POWER(d.stddev_daily_demand, 2) + 
            POWER(d.avg_daily_demand, 2) * POWER(COALESCE(l.stddev_lead_time_days, 3), 2)
        ), 
    0) AS safety_stock_units
FROM demand_stats d
LEFT JOIN lead_time_stats l ON d.material_id = l.material_id
WHERE d.avg_daily_demand > 0;

-- -------------------------------------------
-- 4.2 26-Week Inventory Projection (Americas Only)
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_americas_projection` AS
WITH latest_inventory AS (
    SELECT 
        material_id,
        plant_id,
        SUM(stock_qty_on_hand) AS current_stock,
        SUM(inventory_value_usd) AS current_value
    FROM `scm-coe-hub.scm_analytics.fact_daily_inventory`
    WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM `scm-coe-hub.scm_analytics.fact_daily_inventory`)
    GROUP BY material_id, plant_id
),
weekly_forecast AS (
    SELECT 
        so.material_id,
        so.plant_id,
        AVG(so.ordered_qty) * 7 AS avg_weekly_demand
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON so.plant_id = p.plant_id
    WHERE p.region = 'Americas'
      AND so.create_date >= '2025-04-01'
    GROUP BY so.material_id, so.plant_id
)
SELECT 
    i.plant_id,
    p.plant_name,
    i.material_id,
    m.material_name,
    i.current_stock,
    COALESCE(f.avg_weekly_demand, 0) AS weekly_demand_forecast,
    i.current_stock AS week_0,
    GREATEST(i.current_stock - COALESCE(f.avg_weekly_demand, 0), 0) AS week_1,
    GREATEST(i.current_stock - 2 * COALESCE(f.avg_weekly_demand, 0), 0) AS week_2,
    GREATEST(i.current_stock - 4 * COALESCE(f.avg_weekly_demand, 0), 0) AS week_4,
    GREATEST(i.current_stock - 8 * COALESCE(f.avg_weekly_demand, 0), 0) AS week_8,
    GREATEST(i.current_stock - 13 * COALESCE(f.avg_weekly_demand, 0), 0) AS week_13,
    GREATEST(i.current_stock - 26 * COALESCE(f.avg_weekly_demand, 0), 0) AS week_26,
    CASE 
        WHEN COALESCE(f.avg_weekly_demand, 0) = 0 THEN 999
        ELSE ROUND(i.current_stock / (COALESCE(f.avg_weekly_demand, 0) / 7), 1)
    END AS days_of_supply
FROM latest_inventory i
JOIN `scm-coe-hub.scm_analytics.dim_material` m ON i.material_id = m.material_id
JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON i.plant_id = p.plant_id
LEFT JOIN weekly_forecast f ON i.material_id = f.material_id AND i.plant_id = f.plant_id
WHERE p.region = 'Americas';

-- -------------------------------------------
-- 4.3 Tariff Impact Analysis (Americas)
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_americas_tariff_impact` AS
WITH landed_cost AS (
    SELECT 
        po.material_id,
        m.material_name,
        m.material_category,
        p.country AS importing_country,
        AVG(po.unit_cost) AS base_unit_cost,
        AVG(po.unit_cost) * 0.15 AS estimated_freight,
        AVG(po.unit_cost) * 0.02 AS estimated_insurance,
        CASE 
            WHEN p.country = 'US' THEN 0.25
            WHEN p.country = 'MX' THEN 0.10
            WHEN p.country = 'BR' THEN 0.35
            ELSE 0.15
        END AS tariff_rate
    FROM `scm-coe-hub.scm_analytics.fact_purchase_order` po
    JOIN `scm-coe-hub.scm_analytics.dim_material` m ON po.material_id = m.material_id
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON po.plant_id = p.plant_id
    WHERE p.region = 'Americas'
    GROUP BY po.material_id, m.material_name, m.material_category, p.country
)
SELECT 
    material_id,
    material_name,
    material_category,
    importing_country,
    base_unit_cost,
    estimated_freight,
    estimated_insurance,
    tariff_rate,
    base_unit_cost * tariff_rate AS tariff_amount,
    base_unit_cost + estimated_freight + estimated_insurance + (base_unit_cost * tariff_rate) AS total_landed_cost,
    tariff_rate AS tariff_pct_display
FROM landed_cost;