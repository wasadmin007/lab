output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "function_app_subnet_id" {
  value = azurerm_subnet.function_app.id
}

output "cosmos_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.cosmos.id]
}

output "keyvault_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.keyvault.id]
}
