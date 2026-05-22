output "id" {
  value = azurerm_cosmosdb_account.main.id
}

output "endpoint" {
  value = azurerm_cosmosdb_account.main.endpoint
}

output "account_name" {
  value = azurerm_cosmosdb_account.main.name
}

output "database_name" {
  value = azurerm_cosmosdb_sql_database.main.name
}

output "container_name" {
  value = azurerm_cosmosdb_sql_container.employees.name
}
