output "warehouse_id" {
  description = "SQL warehouse id. Feed this to the Asset Bundle's warehouse_id variable."
  value       = databricks_sql_endpoint.this.id
}

output "warehouse_name" {
  description = "SQL warehouse name."
  value       = databricks_sql_endpoint.this.name
}

output "jdbc_url" {
  description = "JDBC connection string for BI/clients."
  value       = databricks_sql_endpoint.this.jdbc_url
}
