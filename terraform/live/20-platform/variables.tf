variable "environment" {
  description = "Environment name (dev | prod)."
  type        = string
}

# ---- Unity Catalog ----
variable "catalog_name" {
  description = "Catalog name (convention: one per environment)."
  type        = string
}

variable "schema_name" {
  description = "Schema (business domain) within the catalog."
  type        = string
}

variable "volume_name" {
  description = "Landing volume name."
  type        = string
  default     = "landing"
}

variable "admin_group" {
  description = "Group granted ALL_PRIVILEGES on the catalog."
  type        = string
}

variable "data_engineer_group" {
  description = "Unity Catalog account-level principal granted read/write in the catalog (UC grants require account principals, not workspace groups)."
  type        = string
}

variable "warehouse_user_group" {
  description = "Workspace group granted CAN_USE on the SQL warehouse. Warehouse ACLs use workspace groups, which are distinct from UC account principals."
  type        = string
  default     = "users"
}

# ---- SQL warehouse ----
variable "warehouse_name" {
  description = "SQL warehouse display name."
  type        = string
}

variable "warehouse_size" {
  description = "Serverless warehouse T-shirt size."
  type        = string
  default     = "2X-Small"
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}

# ---- Locator for layer 10's remote state ----
# These MUST match terraform/live/10-infra/env/<env>.backend.hcl.
variable "state_resource_group_name" {
  description = "Resource group of the Terraform state storage account."
  type        = string
}

variable "state_storage_account_name" {
  description = "Storage account holding Terraform state."
  type        = string
}

variable "state_container_name" {
  description = "Blob container holding Terraform state."
  type        = string
  default     = "tfstate"
}

variable "infra_state_key" {
  description = "Blob key of layer 10's state file."
  type        = string
}
