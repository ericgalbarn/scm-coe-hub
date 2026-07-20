"""
Synthetic Data Generator for SCM CoE Hub
Generates realistic SCM transactional data mimicking SAP ERP patterns
Sprint 2 - Tuần 2
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import os
from dotenv import load_dotenv
from google.cloud import bigquery

# Load environment variables
load_dotenv()

PROJECT_ID = os.getenv('GCP_PROJECT_ID')
DATASET = os.getenv('BQ_DATASET')

# Set seeds for reproducibility
np.random.seed(42)
random.seed(42)

print("=" * 60)
print("SCM COE HUB - SYNTHETIC DATA GENERATOR")
print(f"Project: {PROJECT_ID}.{DATASET}")
print("=" * 60)

# ============================================
# CONFIG
# ============================================
START_DATE = datetime(2024, 7, 1)
END_DATE = datetime(2025, 6, 30)
DATE_RANGE = (END_DATE - START_DATE).days

# ============================================
# 1. DIM_REGION_PLANT
# ============================================
print("\n[1/5] Generating dim_region_plant...")

plants_data = [
    # Americas
    ('US01', 'Atlanta Distribution Center', 'Americas', 'US', 'Atlanta, GA', False),
    ('US02', 'Chicago Manufacturing Plant', 'Americas', 'US', 'Chicago, IL', True),
    ('US03', 'Dallas Distribution Center', 'Americas', 'US', 'Dallas, TX', False),
    ('MX01', 'Monterrey Manufacturing', 'Americas', 'MX', 'Monterrey', True),
    ('BR01', 'Sao Paulo Distribution', 'Americas', 'BR', 'Sao Paulo', False),
    # Europe
    ('DE01', 'Munich Central DC', 'Europe', 'DE', 'Munich', False),
    ('DE02', 'Hamburg Manufacturing', 'Europe', 'DE', 'Hamburg', True),
    ('UK01', 'London Distribution Hub', 'Europe', 'UK', 'London', False),
    ('FR01', 'Paris Regional DC', 'Europe', 'FR', 'Paris', False),
    ('IT01', 'Milan Manufacturing', 'Europe', 'IT', 'Milan', True),
    # APAC
    ('VN01', 'Hanoi Manufacturing Plant', 'APAC', 'VN', 'Hanoi', True),
    ('VN02', 'Ho Chi Minh Distribution', 'APAC', 'VN', 'Ho Chi Minh City', False),
    ('CN01', 'Shanghai Manufacturing', 'APAC', 'CN', 'Shanghai', True),
    ('JP01', 'Tokyo Distribution Center', 'APAC', 'JP', 'Tokyo', False),
    ('IN01', 'Mumbai Manufacturing', 'APAC', 'IN', 'Mumbai', True),
]

df_plants = pd.DataFrame(plants_data, columns=[
    'plant_id', 'plant_name', 'region', 'country', 'city', 'is_manufacturing_flag'
])
df_plants['created_timestamp'] = datetime.now()
df_plants['updated_timestamp'] = datetime.now()

print(f"   ✅ {len(df_plants)} plants created")

# ============================================
# 2. DIM_MATERIAL
# ============================================
print("\n[2/5] Generating dim_material...")

categories = {
    'FAUCETS': {'prefix': 'FAU', 'lead_time': (14, 30), 'cost': (50, 500), 'weight': (0.5, 5.0)},
    'CERAMICS': {'prefix': 'CER', 'lead_time': (21, 45), 'cost': (100, 1000), 'weight': (2.0, 15.0)},
    'PIPES_FITTINGS': {'prefix': 'PIP', 'lead_time': (7, 21), 'cost': (5, 100), 'weight': (0.1, 3.0)},
    'VALVES': {'prefix': 'VAL', 'lead_time': (14, 28), 'cost': (30, 300), 'weight': (0.3, 4.0)},
    'BATH_FIXTURES': {'prefix': 'BTH', 'lead_time': (21, 60), 'cost': (200, 2000), 'weight': (10.0, 50.0)},
}

materials = []
mat_counter = 1

for cat, cfg in categories.items():
    for i in range(20):  # 20 SKUs mỗi category = 100 total
        mat_id = f"{cfg['prefix']}{mat_counter:04d}"
        materials.append({
            'material_id': mat_id,
            'material_name': f"{cat.replace('_', ' ').title()} Model {mat_counter}",
            'material_category': cat,
            'uom': random.choice(['PC', 'BOX', 'SET']),
            'abc_classification': random.choice(['A', 'B', 'B', 'C', 'C']),  # Weighted
            'standard_lead_time_days': random.randint(*cfg['lead_time']),
            'standard_unit_cost': round(random.uniform(*cfg['cost']), 2),
            'currency': 'USD',
            'unit_weight': round(random.uniform(*cfg['weight']), 2),
            'weight_uom': 'KG',
            'created_timestamp': datetime.now(),
            'updated_timestamp': datetime.now()
        })
        mat_counter += 1

df_materials = pd.DataFrame(materials)
print(f"   ✅ {len(df_materials)} materials created ({len(categories)} categories)")

# ============================================
# 3. FACT_SALES_ORDER
# ============================================
print("\n[3/5] Generating fact_sales_order...")

sales_orders = []
so_counter = 1

# Regional seasonality
peak_months = {
    'Americas': [3, 4, 5, 9, 10, 11],
    'Europe': [3, 4, 5, 9, 10],
    'APAC': [1, 2, 11, 12]
}

for _ in range(3000):
    plant = df_plants.sample(1).iloc[0]
    material = df_materials.sample(1).iloc[0]
    
    # Seasonal demand
    create_date = START_DATE + timedelta(days=random.randint(0, DATE_RANGE))
    is_peak = create_date.month in peak_months.get(plant['region'], [])
    
    # Higher order probability in peak season
    if not is_peak and random.random() > 0.7:
        continue
    
    requested_delivery = create_date + timedelta(days=7)
    
    # OTIF simulation: ~85% on time
    is_on_time = random.random() < 0.85
    
    if is_on_time:
        actual_delivery = requested_delivery + timedelta(days=random.randint(-1, 0))
        status = 'Completed'
        delivered_qty = random.randint(5, 200)
        ordered_qty = delivered_qty
    else:
        delay = random.randint(1, 21)
        actual_delivery = requested_delivery + timedelta(days=delay)
        status = 'Delayed' if random.random() < 0.7 else 'Partial'
        ordered_qty = random.randint(5, 200)
        delivered_qty = int(ordered_qty * random.uniform(0.3, 0.95)) if status == 'Partial' else ordered_qty
    
    sales_orders.append({
        'sales_order_key': f"SO{so_counter:07d}",
        'sales_order_id': f"{so_counter:010d}",
        'sales_order_line': 10,
        'create_date': create_date,
        'requested_delivery_date': requested_delivery,
        'actual_delivery_date': actual_delivery,
        'material_id': material['material_id'],
        'plant_id': plant['plant_id'],
        'region_id': plant['region'],
        'ordered_qty': ordered_qty,
        'delivered_qty': delivered_qty,
        'net_price': round(material['standard_unit_cost'] * 1.2, 2),
        'currency': 'USD',
        'order_status': status,
        'created_timestamp': datetime.now()
    })
    so_counter += 1

df_sales = pd.DataFrame(sales_orders)
print(f"   ✅ {len(df_sales)} sales orders created")
print(f"   OTIF Rate: {(df_sales['order_status'] == 'Completed').mean():.1%}")

# ============================================
# 4. FACT_PURCHASE_ORDER
# ============================================
print("\n[4/5] Generating fact_purchase_order...")

purchase_orders = []
po_counter = 1

vendors = [f"VEND{str(i).zfill(4)}" for i in range(1, 31)]

for _ in range(1500):
    plant = df_plants[df_plants['is_manufacturing_flag'] == False].sample(1).iloc[0]  # DCs receive POs
    material = df_materials.sample(1).iloc[0]
    vendor = random.choice(vendors)
    
    po_date = START_DATE + timedelta(days=random.randint(0, DATE_RANGE))
    lead_time = int(material['standard_lead_time_days'])
    scheduled_delivery = po_date + timedelta(days=lead_time)
    
    # Supplier reliability: ~80% on time
    is_on_time = random.random() < 0.80
    
    if is_on_time:
        actual_receipt = scheduled_delivery + timedelta(days=random.randint(-2, 2))
        status = 'Fully Received'
        ordered_qty = random.randint(50, 500)
        received_qty = ordered_qty
    else:
        delay = random.randint(3, 30)
        actual_receipt = scheduled_delivery + timedelta(days=delay)
        status = random.choice(['Partially Received', 'Delayed'])
        ordered_qty = random.randint(50, 500)
        received_qty = int(ordered_qty * random.uniform(0.4, 0.9))
    
    purchase_orders.append({
        'po_line_key': f"PO{po_counter:07d}",
        'po_id': f"{po_counter:010d}",
        'po_line': 10,
        'po_create_date': po_date,
        'scheduled_delivery_date': scheduled_delivery,
        'actual_goods_receipt_date': actual_receipt,
        'material_id': material['material_id'],
        'plant_id': plant['plant_id'],
        'vendor_id': vendor,
        'ordered_qty': ordered_qty,
        'received_qty': received_qty,
        'unit_cost': material['standard_unit_cost'],
        'currency': 'USD',
        'po_status': status,
        'created_timestamp': datetime.now()
    })
    po_counter += 1

df_purchase = pd.DataFrame(purchase_orders)
print(f"   ✅ {len(df_purchase)} purchase orders created")
print(f"   On-Time Delivery Rate: {(df_purchase['po_status'] == 'Fully Received').mean():.1%}")

# ============================================
# 5. FACT_DAILY_INVENTORY
# ============================================
print("\n[5/5] Generating fact_daily_inventory...")

inventory_records = []
inv_counter = 1

# Generate 365 days of snapshots
for day_offset in range(0, DATE_RANGE, 1):  # Daily snapshots
    snapshot_date = START_DATE + timedelta(days=day_offset)
    
    # Not all plants have all materials every day (sparse matrix)
    for _, plant in df_plants.iterrows():
        # Each plant has 60-80% of materials in stock
        n_materials = random.randint(60, 80)
        selected_materials = df_materials.sample(n=n_materials)
        
        for _, material in selected_materials.iterrows():
            # Stock levels vary by ABC class
            if material['abc_classification'] == 'A':
                stock_range = (20, 100)
            elif material['abc_classification'] == 'B':
                stock_range = (10, 200)
            else:
                stock_range = (0, 500)
            
            stock_qty = random.randint(*stock_range)
            blocked_qty = random.randint(0, int(stock_qty * 0.05))  # ~5% blocked
            
            inventory_records.append({
                'inventory_key': f"INV{inv_counter:010d}",
                'snapshot_date': snapshot_date,
                'material_id': material['material_id'],
                'plant_id': plant['plant_id'],
                'storage_location': random.choice(['A01', 'A02', 'B01', 'C01']),
                'stock_qty_on_hand': stock_qty,
                'blocked_stock_qty': blocked_qty,
                'standard_unit_cost': material['standard_unit_cost'],
                'inventory_value_usd': round(stock_qty * material['standard_unit_cost'], 2),
                'created_timestamp': datetime.now()
            })
            inv_counter += 1

df_inventory = pd.DataFrame(inventory_records)
print(f"   ✅ {len(df_inventory)} inventory records created")
print(f"   Coverage: {df_inventory['snapshot_date'].nunique()} days × {df_inventory['plant_id'].nunique()} plants")

# ============================================
# SUMMARY
# ============================================
print("\n" + "=" * 60)
print("DATA GENERATION COMPLETE")
print("=" * 60)
print(f"   dim_region_plant:    {len(df_plants):>6,} rows")
print(f"   dim_material:        {len(df_materials):>6,} rows")
print(f"   fact_sales_order:    {len(df_sales):>6,} rows")
print(f"   fact_purchase_order: {len(df_purchase):>6,} rows")
print(f"   fact_daily_inventory:{len(df_inventory):>6,} rows")
print(f"   TOTAL:               {len(df_plants)+len(df_materials)+len(df_sales)+len(df_purchase)+len(df_inventory):>6,} rows")
print("\n➡️  Ready to load to BigQuery. Run load_to_bigquery.py next.")