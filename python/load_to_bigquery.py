"""
Load generated data from pandas DataFrames to BigQuery
Reuses the generator functions, then uploads directly
"""
import os
import sys
from dotenv import load_dotenv
from google.cloud import bigquery

load_dotenv()

PROJECT_ID = os.getenv('GCP_PROJECT_ID')
DATASET = os.getenv('BQ_DATASET')

print("=" * 60)
print("LOADING DATA TO BIGQUERY")
print(f"Destination: {PROJECT_ID}.{DATASET}")
print("=" * 60)

# Import the generator module
sys.path.append(os.path.dirname(__file__))
from generate_data import (
    df_plants, df_materials, df_sales, df_purchase, df_inventory
)

client = bigquery.Client()

# Mapping: variable name -> table name
tables = {
    'df_plants': ('dim_region_plant', df_plants),
    'df_materials': ('dim_material', df_materials),
    'df_sales': ('fact_sales_order', df_sales),
    'df_purchase': ('fact_purchase_order', df_purchase),
    'df_inventory': ('fact_daily_inventory', df_inventory),
}

for var_name, (table_name, df) in tables.items():
    table_id = f"{PROJECT_ID}.{DATASET}.{table_name}"
    
    print(f"\n📤 Loading {table_name}...")
    print(f"   Rows: {len(df):,}")
    print(f"   Columns: {len(df.columns)}")
    
    # Load to BigQuery (overwrite if exists)
    job = client.load_table_from_dataframe(
        df, table_id,
        job_config=bigquery.LoadJobConfig(
            write_disposition="WRITE_TRUNCATE"  # Overwrite table
        )
    )
    
    job.result()  # Wait for completion
    
    # Verify
    actual_table = client.get_table(table_id)
    print(f"   ✅ Loaded: {actual_table.num_rows:,} rows in {table_name}")

print("\n" + "=" * 60)
print("ALL DATA LOADED SUCCESSFULLY!")
print("=" * 60)
print("\nVerify in BigQuery:")
print(f"SELECT table_name, row_count")
print(f"FROM `{PROJECT_ID}.{DATASET}.__TABLES__`")
print(f"ORDER BY table_name;")