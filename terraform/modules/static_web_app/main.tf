resource "azurerm_static_web_app" "main" {
  name                = "swa-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = var.sku_tier
  sku_size            = var.sku_tier
  tags                = var.tags
}
