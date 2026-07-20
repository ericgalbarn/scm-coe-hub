-- ============================================
-- FACT_SALES_ORDER: Customer Order Transactions
-- ============================================
CREATE OR REPLACE TABLE `scm-coe-hub.scm_analytics.fact_sales_order` (
    sales_order_key STRING NOT NULL,
    sales_order_id STRING NOT NULL,
    sales_order_line INT64 NOT NULL,
    create_date DATE NOT NULL,
    requested_delivery_date DATE NOT NULL,
    actual_delivery_date DATE,
    material_id STRING NOT NULL,
    plant_id STRING NOT NULL,
    region_id STRING,
    ordered_qty NUMERIC NOT NULL,
    delivered_qty NUMERIC,
    net_price NUMERIC,
    currency STRING DEFAULT 'USD',
    order_status STRING,
    
    -- Metadata
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY create_date
CLUSTER BY region_id, plant_id, material_id
OPTIONS (
    description = 'Sales order fact table - partitioned by create date'
);