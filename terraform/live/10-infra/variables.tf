variable "environment" {
  description = "Environment name (dev | prod). Drives tags and naming."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Resource group to create for the workspace."
  type        = string
}

variable "workspace_name" {
  description = "Azure Databricks workspace name."
  type        = string
}

variable "sku" {
  description = "Workspace tier (premium required for Unity Catalog)."
  type        = string
  default     = "premium"
}

variable "uc_storage_account_name" {
  description = "ADLS Gen2 storage account for the Unity Catalog managed location (globally unique, 3-24 lowercase alphanumeric)."
  type        = string
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
