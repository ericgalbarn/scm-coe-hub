-- ============================================
-- DIM_MATERIAL: Product Master Data
-- ============================================
CREATE OR REPLACE TABLE `scm-coe-hub.scm_analytics.dim_material` (
    material_id STRING NOT NULL,
    material_name STRING NOT NULL,
    material_category STRING NOT NULL,
    uom STRING NOT NULL,
    abc_classification STRING,
    standard_lead_time_days INT64,
    standard_unit_cost NUMERIC,
    currency STRING DEFAULT 'USD',
    unit_weight NUMERIC,
    weight_uom STRING DEFAULT 'KG',
    
    -- Metadata
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY material_category, abc_classification
OPTIONS (
    description = 'Material master dimension table'
);