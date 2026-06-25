variable "warehouse_name" {
  description = "Display name of the SQL warehouse."
  type        = string
}

variable "cluster_size" {
  description = "Serverless T-shirt size. The dbsql skill recommends starting larger and scaling down for prod analytics; 2X-Small is fine for dev/demo."
  type        = string
  default     = "2X-Small"
}

variable "auto_stop_minutes" {
  description = "Idle minutes before auto-stop. Serverless bills only while running, so keep this low."
  type        = number
  default     = 10
}

variable "max_num_clusters" {
  description = "Upper bound for autoscaling under concurrent load."
  type        = number
  default     = 1
}

variable "data_engineer_group" {
  description = "Group granted CAN_USE on the warehouse."
  type        = string
}

variable "tags" {
  description = "Custom tags for cost allocation."
  type        = map(string)
  default     = {}
}
