output "principal_id" {
  description = "Object ID of the system-assigned managed identity"
  value       = azurerm_linux_function_app.main.identity[0].principal_id
}

output "default_hostname" {
  value = azurerm_linux_function_app.main.default_hostname
}

output "name" {
  value = azurerm_linux_function_app.main.name
}
