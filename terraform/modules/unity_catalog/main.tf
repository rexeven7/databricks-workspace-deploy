terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.50"
    }
  }
}

# A catalog is the top of the Unity Catalog three-level namespace
# (catalog.schema.table). Best practice (ai-dev-kit databricks-dbsql skill):
# isolate ENVIRONMENTS at the catalog level and business DOMAINS at the schema
# level. So dev/prod become separate catalogs, "sales"/"marketing" become schemas.
resource "databricks_catalog" "this" {
  name           = var.catalog_name
  comment        = var.catalog_comment
  isolation_mode = "ISOLATED" # bound only to workspaces you explicitly grant, not every workspace on the metastore

  properties = {
    environment = var.environment
  }
}

resource "databricks_schema" "this" {
  catalog_name = databricks_catalog.this.name
  name         = var.schema_name
  comment      = "Domain schema for the ${var.environment} environment. Managed by Terraform."
}

# MANAGED volume for raw/unstructured files that land before being read into
# Delta. Managed (vs external) volumes get predictive optimization and full
# UC governance with no storage credential wiring.
resource "databricks_volume" "landing" {
  name         = var.volume_name
  catalog_name = databricks_catalog.this.name
  schema_name  = databricks_schema.this.name
  volume_type  = "MANAGED"
  comment      = "Landing volume for raw files. Managed by Terraform."
}

# Least-privilege grants. Granting at the CATALOG level cascades to its schemas,
# tables and volumes. Note (ai-dev-kit databricks-bundles skill): volumes use
# READ_VOLUME / WRITE_VOLUME, which differ from table privileges — both are
# included here so engineers can use the landing volume.
resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.this.name

  grant {
    principal  = var.admin_group
    privileges = ["ALL_PRIVILEGES"]
  }

  grant {
    principal = var.data_engineer_group
    privileges = [
      "USE_CATALOG",
      "USE_SCHEMA",
      "CREATE_SCHEMA",
      "CREATE_TABLE",
      "SELECT",
      "MODIFY",
      "READ_VOLUME",
      "WRITE_VOLUME",
    ]
  }
}
