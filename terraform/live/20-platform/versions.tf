terraform {
  # 1.7 introduced override_data/override_resource, used in tests/ to stub the
  # remote-state lookup so platform tests run fully offline.
  required_version = ">= 1.7.0"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.57"
    }
  }
}
