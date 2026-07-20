-- ============================================
-- FACT_DAILY_INVENTORY: Daily Stock Snapshots
-- ============================================
CREATE OR REPLACE TABLE `scm-coe-hub.scm_analytics.fact_daily_inventory` (
    inventory_key STRING NOT NULL,
    snapshot_date DATE NOT NULL,
    material_id STRING NOT NULL,
    plant_id STRING NOT NULL,
    storage_location STRING NOT NULL,
    stock_qty_on_hand NUMERIC NOT NULL,
    blocked_stock_qty NUMERIC DEFAULT 0,
    standard_unit_cost NUMERIC,
    inventory_value_usd NUMERIC,
    
    -- Metadata
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY snapshot_date
CLUSTER BY plant_id, material_id
OPTIONS (
    description = 'Daily inventory snapshot fact table'
);