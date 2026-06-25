variable "catalog_name" {
  description = "Catalog name. Convention: one catalog per environment (e.g. 'dev', 'prod')."
  type        = string
}

variable "schema_name" {
  description = "Schema (database) within the catalog. Convention: one schema per business domain."
  type        = string
}

variable "volume_name" {
  description = "Managed volume for landing raw/unstructured files."
  type        = string
  default     = "landing"
}

variable "catalog_comment" {
  description = "Catalog description (shown in Catalog Explorer)."
  type        = string
  default     = "Provisioned by Terraform."
}

variable "environment" {
  description = "Environment label, stored as a catalog property and used in comments."
  type        = string
}

variable "admin_group" {
  description = "Group granted ALL_PRIVILEGES on the catalog (platform/data-governance owners)."
  type        = string
}

variable "data_engineer_group" {
  description = "Group granted day-to-day read/write within the catalog."
  type        = string
}

# ---- Managed location (required on UC Default Storage accounts) ----
variable "access_connector_id" {
  description = "Azure resource ID of the Databricks access connector backing the storage credential."
  type        = string
}

variable "storage_credential_name" {
  description = "Name of the Unity Catalog storage credential."
  type        = string
}

variable "external_location_name" {
  description = "Name of the Unity Catalog external location."
  type        = string
}

variable "storage_location_url" {
  description = "ADLS Gen2 container root (no trailing slash). The catalog's managed location is a subpath of this."
  type        = string
}
