locals {
  suffix = "${var.project_name}-${var.environment}"
  tags   = merge(var.tags, { environment = var.environment })
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.suffix}"
  location = var.location
  tags     = local.tags
}

# ── Networking ──────────────────────────────────────────────────────────────
module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  suffix              = local.suffix
  tags                = local.tags
}

# ── Key Vault ────────────────────────────────────────────────────────────────
module "key_vault" {
  source                     = "./modules/key_vault"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  suffix                     = local.suffix
  tags                       = local.tags
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  deployer_object_id         = data.azurerm_client_config.current.object_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  private_dns_zone_ids       = module.networking.keyvault_private_dns_zone_ids
}

# ── Cosmos DB ────────────────────────────────────────────────────────────────
module "cosmos_db" {
  source                     = "./modules/cosmos_db"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  suffix                     = local.suffix
  tags                       = local.tags
  throughput                 = var.cosmos_throughput
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  private_dns_zone_ids       = module.networking.cosmos_private_dns_zone_ids
}

# ── Static Web App (created before Function App so its hostname is available
#    for CORS configuration on the Function App) ────────────────────────────
module "static_web_app" {
  source              = "./modules/static_web_app"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  suffix              = local.suffix
  tags                = local.tags
  sku_tier            = var.static_web_app_sku_tier
}

# ── Function App ──────────────────────────────────────────────────────────────
module "function_app" {
  source                     = "./modules/function_app"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  suffix                     = local.suffix
  tags                       = local.tags
  cosmos_db_endpoint         = module.cosmos_db.endpoint
  cosmos_db_name             = module.cosmos_db.database_name
  cosmos_container_name      = module.cosmos_db.container_name
  key_vault_id               = module.key_vault.id
  vnet_integration_subnet_id = module.networking.function_app_subnet_id
  # Lock CORS to the SWA origin; avoids wildcard in production
  allowed_origins = ["https://${module.static_web_app.default_host_name}"]
}

# ── RBAC: Function App MI → Cosmos DB Data Contributor ──────────────────────
# Built-in role 00000000-…-0002 = Cosmos DB Built-in Data Contributor
# (allows reads + writes; use Data Reader 00000000-…-0001 for read-only APIs)
resource "azurerm_cosmosdb_sql_role_assignment" "function_app" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = module.cosmos_db.account_name
  role_definition_id  = "${module.cosmos_db.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = module.function_app.principal_id
  scope               = module.cosmos_db.id
}

# ── RBAC: Function App MI → Key Vault Secrets User ───────────────────────────
resource "azurerm_role_assignment" "func_kv_secrets" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.function_app.principal_id
}
