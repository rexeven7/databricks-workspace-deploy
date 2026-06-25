terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.50"
    }
  }
}

# Serverless SQL warehouse. Per the ai-dev-kit databricks-dbsql skill, serverless
# is the recommended default: sub-minute start, Intelligent Workload Management,
# and Photon + Predictive Query Execution on by default. You pay only while
# queries run, so a low auto_stop keeps idle cost near zero.
resource "databricks_sql_endpoint" "this" {
  name                      = var.warehouse_name
  cluster_size              = var.cluster_size
  auto_stop_mins            = var.auto_stop_minutes
  max_num_clusters          = var.max_num_clusters
  enable_serverless_compute = true
  warehouse_type            = "PRO" # required for serverless

  dynamic "tags" {
    for_each = length(var.tags) > 0 ? [1] : []
    content {
      dynamic "custom_tags" {
        for_each = var.tags
        content {
          key   = custom_tags.key
          value = custom_tags.value
        }
      }
    }
  }
}

# Least-privilege: engineers can use the warehouse but not manage it.
resource "databricks_permissions" "this" {
  sql_endpoint_id = databricks_sql_endpoint.this.id

  access_control {
    group_name       = var.data_engineer_group
    permission_level = "CAN_USE"
  }
}
