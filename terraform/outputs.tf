output "resource_group_name" {
  description = "Name of the deployed resource group"
  value       = azurerm_resource_group.main.name
}

output "static_web_app_url" {
  description = "Public URL of the employee portal"
  value       = "https://${module.static_web_app.default_host_name}"
}

output "static_web_app_deployment_token" {
  description = "Deployment token used by the CI/CD pipeline for Static Web Apps"
  value       = module.static_web_app.api_key
  sensitive   = true
}

output "function_app_url" {
  description = "Base URL for the Function App API (append /employees, etc.)"
  value       = "https://${module.function_app.default_hostname}/api"
}

output "function_app_name" {
  description = "Function App resource name (used by azure/functions-action in CI)"
  value       = module.function_app.name
}

output "cosmos_db_endpoint" {
  description = "Cosmos DB endpoint (reachable only via private endpoint within the VNet)"
  value       = module.cosmos_db.endpoint
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.vault_uri
}
