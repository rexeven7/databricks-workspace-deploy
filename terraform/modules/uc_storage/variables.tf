variable "access_connector_name" {
  description = "Name of the Databricks access connector (managed identity for UC storage access)."
  type        = string
}

variable "storage_account_name" {
  description = "ADLS Gen2 storage account for the catalog's managed location (globally unique, 3-24 lowercase alphanumeric)."
  type        = string
}

variable "container_name" {
  description = "Container holding Unity Catalog managed data."
  type        = string
  default     = "ucdata"
}

variable "resource_group_name" {
  description = "Resource group to create these resources in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tags" {
  description = "Tags."
  type        = map(string)
  default     = {}
}
