-- ============================================
-- SCM KPI VIEWS - Sprint 3
-- Executive Dashboard Data Sources
-- ============================================

-- -------------------------------------------
-- 3.1 OTIF% Summary by Region & Month
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_otif_summary` AS
SELECT 
    p.region,
    p.country,
    p.plant_id,
    p.plant_name,
    DATE_TRUNC(so.create_date, MONTH) AS order_month,
    COUNT(DISTINCT so.sales_order_key) AS total_orders,
    COUNT(DISTINCT CASE 
        WHEN so.actual_delivery_date <= so.requested_delivery_date 
        AND so.delivered_qty >= so.ordered_qty 
        THEN so.sales_order_key 
    END) AS otif_orders,
    ROUND(
        COUNT(DISTINCT CASE 
            WHEN so.actual_delivery_date <= so.requested_delivery_date 
            AND so.delivered_qty >= so.ordered_qty 
            THEN so.sales_order_key 
        END) * 100.0 / COUNT(DISTINCT so.sales_order_key), 
    1
    ) AS otif_percentage,
    -- Target
    95.0 AS otif_target
FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p 
    ON so.plant_id = p.plant_id
GROUP BY p.region, p.country, p.plant_id, p.plant_name, order_month;

-- -------------------------------------------
-- 3.2 Current Inventory Value by Plant
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_inventory_value` AS
SELECT 
    p.region,
    p.country,
    p.plant_id,
    p.plant_name,
    p.is_manufacturing_flag,
    inv.snapshot_date,
    SUM(inv.inventory_value_usd) AS total_inventory_value,
    COUNT(DISTINCT inv.material_id) AS unique_skus
FROM `scm-coe-hub.scm_analytics.fact_daily_inventory` inv
JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p 
    ON inv.plant_id = p.plant_id
WHERE inv.snapshot_date = (SELECT MAX(snapshot_date) FROM `scm-coe-hub.scm_analytics.fact_daily_inventory`)
GROUP BY p.region, p.country, p.plant_id, p.plant_name, p.is_manufacturing_flag, inv.snapshot_date;

-- -------------------------------------------
-- 3.3 Backorder Rate
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_backorder_rate` AS
SELECT 
    p.region,
    DATE_TRUNC(so.requested_delivery_date, MONTH) AS delivery_month,
    COUNT(DISTINCT so.sales_order_key) AS total_scheduled,
    COUNT(DISTINCT CASE 
        WHEN so.actual_delivery_date > so.requested_delivery_date 
        THEN so.sales_order_key 
    END) AS backordered,
    ROUND(
        COUNT(DISTINCT CASE 
            WHEN so.actual_delivery_date > so.requested_delivery_date 
            THEN so.sales_order_key 
        END) * 100.0 / COUNT(DISTINCT so.sales_order_key), 
    1
    ) AS backorder_rate_pct
FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p 
    ON so.plant_id = p.plant_id
GROUP BY p.region, delivery_month;

-- -------------------------------------------
-- 3.4 Inventory Turns (Annualized)
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_inventory_turns` AS
WITH monthly_cogs AS (
    -- COGS = Sum of inventory value consumed (approximated from sales)
    SELECT 
        p.region,
        DATE_TRUNC(so.create_date, MONTH) AS order_month,
        SUM(so.delivered_qty) AS total_units_sold
    FROM `scm-coe-hub.scm_analytics.fact_sales_order` so
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p 
        ON so.plant_id = p.plant_id
    WHERE so.order_status IN ('Completed', 'Delayed')
    GROUP BY p.region, order_month
),
avg_inventory_value AS (
    SELECT 
        p.region,
        DATE_TRUNC(inv.snapshot_date, MONTH) AS inv_month,
        AVG(inv.inventory_value_usd) AS avg_inventory_value
    FROM `scm-coe-hub.scm_analytics.fact_daily_inventory` inv
    JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p 
        ON inv.plant_id = p.plant_id
    GROUP BY p.region, inv_month
),
avg_unit_cost AS (
    -- Get average unit cost per region to convert units to dollars
    SELECT 
        p.region,
        AVG(m.standard_unit_cost) AS avg_cost
    FROM `scm-coe-hub.scm_analytics.dim_material` m
    CROSS JOIN `scm-coe-hub.scm_analytics.dim_region_plant` p
    GROUP BY p.region
)
SELECT 
    c.region,
    c.order_month,
    ROUND((c.total_units_sold * uc.avg_cost) / NULLIF(a.avg_inventory_value, 0) * 12, 2) AS annualized_turns,
    8.0 AS target_turns
FROM monthly_cogs c
JOIN avg_inventory_value a 
    ON c.region = a.region AND c.order_month = a.inv_month
JOIN avg_unit_cost uc
    ON c.region = uc.region;

-- -------------------------------------------
-- 3.5 Monthly SCM Performance Trend (Combined KPIs)
-- -------------------------------------------
CREATE OR REPLACE VIEW `scm-coe-hub.scm_analytics.v_monthly_trend` AS
SELECT 
    o.order_month AS month,
    o.region,
    o.otif_percentage,
    b.backorder_rate_pct,
    t.annualized_turns,
    o.otif_target,
    t.target_turns
FROM `scm-coe-hub.scm_analytics.v_otif_summary` o
LEFT JOIN `scm-coe-hub.scm_analytics.v_backorder_rate` b 
    ON o.region = b.region AND o.order_month = b.delivery_month
LEFT JOIN `scm-coe-hub.scm_analytics.v_inventory_turns` t 
    ON o.region = t.region AND o.order_month = t.order_month;