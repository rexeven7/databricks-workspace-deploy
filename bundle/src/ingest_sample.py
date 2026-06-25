# Databricks notebook source
# MAGIC %md
# MAGIC # Sample medallion ingestion (deployed via Databricks Asset Bundles)
# MAGIC
# MAGIC Reads a built-in Databricks sample dataset and writes a governed, **managed,
# MAGIC liquid-clustered** Delta table into the Unity Catalog catalog/schema that
# MAGIC Terraform provisioned (layer 20). Practices below come from the ai-dev-kit
# MAGIC `databricks-dbsql` skill: managed tables, Liquid Clustering over partitioning,
# MAGIC `CREATE OR REPLACE` (preserves time travel), `DECIMAL` for money, and `ANALYZE`.

# COMMAND ----------
# Parameters arrive as widgets from the job's parameters (set by the bundle).
dbutils.widgets.text("catalog", "dev")
dbutils.widgets.text("schema", "sales")

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")
target_table = f"{catalog}.{schema}.trips_curated"
print(f"Target table: {target_table}")

# COMMAND ----------
from pyspark.sql import functions as F

# `samples` is a built-in catalog available in every Unity Catalog workspace.
trips = spark.read.table("samples.nyctaxi.trips")

curated = (
    trips.where(F.col("trip_distance") > 0)
    .withColumn(
        "fare_per_mile",
        F.round(F.col("fare_amount") / F.col("trip_distance"), 2),
    )
    .select(
        "tpep_pickup_datetime",
        "tpep_dropoff_datetime",
        "trip_distance",
        F.col("fare_amount").cast("decimal(10,2)").alias("fare_amount"),  # DECIMAL for money
        "fare_per_mile",
        "pickup_zip",
        "dropoff_zip",
    )
)

curated.createOrReplaceTempView("curated_trips")

# COMMAND ----------
# CREATE OR REPLACE + CLUSTER BY: Databricks' recommended layout for all new
# tables (Liquid Clustering replaces partitioning/Z-ORDER). 1-4 keys, chosen
# from the most frequently filtered columns.
spark.sql(
    f"""
    CREATE OR REPLACE TABLE {target_table}
    CLUSTER BY (pickup_zip, tpep_pickup_datetime)
    COMMENT 'Curated NYC taxi trips. Managed by the sample-integration bundle.'
    AS SELECT * FROM curated_trips
    """
)

# Column statistics help Adaptive Query Execution and data skipping.
spark.sql(f"ANALYZE TABLE {target_table} COMPUTE STATISTICS FOR ALL COLUMNS")

# COMMAND ----------
display(spark.sql(f"SELECT * FROM {target_table} LIMIT 20"))
