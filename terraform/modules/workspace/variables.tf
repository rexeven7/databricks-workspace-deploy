variable "workspace_name" {
  description = "Name of the Azure Databricks workspace."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that will contain the workspace resource."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. eastus2."
  type        = string
}

variable "sku" {
  description = "Workspace tier. 'premium' is required for Unity Catalog, RBAC and serverless SQL."
  type        = string
  default     = "premium"

  validation {
    condition     = contains(["standard", "premium"], var.sku)
    error_message = "sku must be 'standard' or 'premium'. Unity Catalog requires 'premium'."
  }
}

variable "managed_resource_group_name" {
  description = "Optional name for the Databricks-managed resource group. Null lets Azure generate one."
  type        = string
  default     = null
}

variable "public_network_access_enabled" {
  description = "Whether the workspace is reachable from the public internet. Set false for VNet-injected / Private Link deployments."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for cost allocation, ownership and environment."
  type        = map(string)
  default     = {}
}
