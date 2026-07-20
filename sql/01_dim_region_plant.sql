-- ============================================
-- DIM_REGION_PLANT: Organizational Structure
-- ============================================
CREATE OR REPLACE TABLE `scm-coe-hub.scm_analytics.dim_region_plant` (
    plant_id STRING NOT NULL,
    plant_name STRING NOT NULL,
    region STRING NOT NULL,
    country STRING NOT NULL,
    city STRING NOT NULL,
    is_manufacturing_flag BOOL NOT NULL,
    
    -- Metadata
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_timestamp)
CLUSTER BY region, country
OPTIONS (
    description = 'Plant and regional hierarchy dimension table'
);