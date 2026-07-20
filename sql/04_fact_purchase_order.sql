-- ============================================
-- FACT_PURCHASE_ORDER: Procurement Transactions
-- ============================================
CREATE OR REPLACE TABLE `scm-coe-hub.scm_analytics.fact_purchase_order` (
    po_line_key STRING NOT NULL,
    po_id STRING NOT NULL,
    po_line INT64 NOT NULL,
    po_create_date DATE NOT NULL,
    scheduled_delivery_date DATE,
    actual_goods_receipt_date DATE,
    material_id STRING NOT NULL,
    plant_id STRING NOT NULL,
    vendor_id STRING,
    ordered_qty NUMERIC NOT NULL,
    received_qty NUMERIC,
    unit_cost NUMERIC,
    currency STRING DEFAULT 'USD',
    po_status STRING,
    
    -- Metadata
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY po_create_date
CLUSTER BY plant_id, vendor_id
OPTIONS (
    description = 'Purchase order fact table - partitioned by PO create date'
);