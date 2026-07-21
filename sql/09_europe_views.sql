-- ============================================
-- EUROPE REGIONAL ANALYTICS - Sprint 5
-- Views: Vendor Delivery Delay, Slow-Moving Stock, Reallocation Matrix
-- ============================================

-- -------------------------------------------
-- 5.1 Vendor Delivery Delay Analysis
-- Question: Which vendors are delaying deliveries the most?
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_europe_delivery_delay` AS
SELECT 
    po.vendor_id,
    po.plant_id,
    p.plant_name,
    p.country AS plant_country,
    AVG(DATE_DIFF(DATE(po.actual_goods_receipt_date), DATE(po.scheduled_delivery_date), DAY)) AS avg_delay_days,
    COUNT(*) AS total_deliveries,
    COUNT(CASE WHEN DATE(po.actual_goods_receipt_date) > DATE(po.scheduled_delivery_date) THEN 1 END) AS late_deliveries,
    ROUND(
        COUNT(CASE WHEN DATE(po.actual_goods_receipt_date) > DATE(po.scheduled_delivery_date) THEN 1 END) * 100.0 / COUNT(*), 
    1) AS late_delivery_pct
FROM `scm-coe-hub.scm_analytics.fact_purchase_order` po
JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON po.plant_id = p.plant_id
WHERE p.region = 'Europe'
  AND po.actual_goods_receipt_date IS NOT NULL
  AND po.scheduled_delivery_date IS NOT NULL
GROUP BY po.vendor_id, po.plant_id, p.plant_name, p.country;

-- -------------------------------------------
-- 5.2 Slow-Moving Stock Screening (>180 Days of Supply)
-- Question: How much cash is trapped in slow-moving inventory?
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_europe_slow_moving` AS
WITH current_stock AS (
    SELECT 
        material_id,
        plant_id,
        SUM(stock_qty_on_hand) AS stock_qty,
        SUM(inventory_value_usd) AS stock_value
    FROM `scm-coe-hub.scm_analytics.fact_daily_inventory`
    WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM `scm-coe-hub.scm_analytics.fact_daily_inventory`)
    GROUP BY material_id, plant_id
),
daily_demand AS (
    SELECT 
        so.material_id,
        so.plant_id,
        AVG(so.ordered_qty) AS avg_daily_demand
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON so.plant_id = p.plant_id
    WHERE p.region = 'Europe'
      AND so.create_date >= '2025-01-01'
    GROUP BY so.material_id, so.plant_id
)
SELECT 
    cs.plant_id,
    p.plant_name,
    p.country,
    cs.material_id,
    m.material_name,
    m.material_category,
    cs.stock_qty,
    cs.stock_value,
    COALESCE(d.avg_daily_demand, 0) AS avg_daily_demand,
    CASE 
        WHEN COALESCE(d.avg_daily_demand, 0) = 0 THEN 999
        ELSE ROUND(cs.stock_qty / d.avg_daily_demand, 1)
    END AS days_of_supply
FROM current_stock cs
JOIN `scm-coe-hub.scm_analytics.dim_material` m ON cs.material_id = m.material_id
JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON cs.plant_id = p.plant_id
LEFT JOIN daily_demand d ON cs.material_id = d.material_id AND cs.plant_id = d.plant_id
WHERE p.region = 'Europe'
  AND (
      COALESCE(d.avg_daily_demand, 0) = 0 
      OR ROUND(cs.stock_qty / NULLIF(d.avg_daily_demand, 0), 1) > 180
  );

-- -------------------------------------------
-- 5.3 Inter-Company Reallocation Matrix
-- Question: Can we transfer stock from surplus to deficit plants and save money?
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_europe_reallocation` AS
WITH all_europe_stock AS (
    SELECT 
        inv.plant_id,
        p.plant_name,
        inv.material_id,
        m.material_name,
        m.material_category,
        SUM(inv.stock_qty_on_hand) AS stock_qty,
        SUM(inv.inventory_value_usd) AS stock_value
    FROM `scm-coe-hub.scm_analytics.fact_daily_inventory` inv
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON inv.plant_id = p.plant_id
    JOIN `scm-coe-hub.scm_analytics.dim_material` m ON inv.material_id = m.material_id
    WHERE p.region = 'Europe'
      AND inv.snapshot_date = (SELECT MAX(snapshot_date) FROM `scm-coe-hub.scm_analytics.fact_daily_inventory`)
    GROUP BY inv.plant_id, p.plant_name, inv.material_id, m.material_name, m.material_category
),
daily_demand AS (
    SELECT 
        so.material_id,
        so.plant_id,
        AVG(so.ordered_qty) AS avg_daily_demand
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p ON so.plant_id = p.plant_id
    WHERE p.region = 'Europe'
      AND so.create_date >= '2025-01-01'
    GROUP BY so.material_id, so.plant_id
),
stock_with_dos AS (
    SELECT 
        s.*,
        COALESCE(d.avg_daily_demand, 0) AS avg_daily_demand,
        CASE 
            WHEN COALESCE(d.avg_daily_demand, 0) = 0 THEN 999
            ELSE ROUND(s.stock_qty / d.avg_daily_demand, 1)
        END AS days_of_supply,
        ROUND(s.stock_value * 0.20 / 12, 2) AS monthly_holding_cost
    FROM all_europe_stock s
    LEFT JOIN daily_demand d ON s.material_id = d.material_id AND s.plant_id = d.plant_id
),
surplus AS (
    SELECT * FROM stock_with_dos WHERE days_of_supply > 180
),
deficit AS (
    SELECT * FROM stock_with_dos WHERE days_of_supply < 30
)
SELECT 
    s.plant_id AS surplus_plant,
    s.plant_name AS surplus_plant_name,
    d.plant_id AS deficit_plant,
    d.plant_name AS deficit_plant_name,
    s.material_id,
    s.material_name,
    s.material_category,
    s.days_of_supply AS surplus_dos,
    d.days_of_supply AS deficit_dos,
    s.stock_qty AS surplus_qty,
    d.stock_qty AS deficit_qty,
    LEAST(s.stock_qty * 0.5, 100) AS suggested_transfer_qty,
    s.monthly_holding_cost,
    ROUND(LEAST(s.stock_qty * 0.5, 100) * 2.50, 2) AS estimated_freight_cost,
    ROUND(s.monthly_holding_cost - (LEAST(s.stock_qty * 0.5, 100) * 2.50), 2) AS reallocation_savings,
    CASE 
        WHEN s.monthly_holding_cost - (LEAST(s.stock_qty * 0.5, 100) * 2.50) > 0 
        THEN '✅ APPROVE'
        ELSE '❌ REJECT'
    END AS recommendation
FROM surplus s
JOIN deficit d ON s.material_id = d.material_id AND s.plant_id != d.plant_id
WHERE s.monthly_holding_cost - (LEAST(s.stock_qty * 0.5, 100) * 2.50) > 0;