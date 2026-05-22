resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  # Storage account names: lowercase alphanumeric only, 3-24 chars
  storage_name = "st${substr(replace(var.suffix, "-", ""), 0, 16)}fn"
  func_name    = "func-${var.suffix}-${random_string.suffix.result}"
}

# ── Storage Account (Functions runtime) ──────────────────────────────────────
resource "azurerm_storage_account" "main" {
  name                            = local.storage_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

# ── Application Insights ─────────────────────────────────────────────────────
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  tags                = var.tags
}

# ── App Service Plan ─────────────────────────────────────────────────────────
# EP1 (Elastic Premium) is the minimum SKU that supports regional VNet
# integration for outbound traffic. Consumption plans only support VNet
# integration on Flex Consumption, which has different cold-start trade-offs.
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "EP1"
  tags                = var.tags
}

# ── Function App ─────────────────────────────────────────────────────────────
resource "azurerm_linux_function_app" "main" {
  name                       = local.func_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  https_only                 = true

  # System-assigned managed identity; its principal_id is used for RBAC
  # assignments (Cosmos DB data access, Key Vault secrets) in the root module
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      node_version = "20"
    }

    # Route all outbound traffic through the VNet so private endpoint DNS
    # resolution resolves to private IPs rather than public ones
    vnet_route_all_enabled = true
    always_on              = true

    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string

    cors {
      # Locked to the Static Web App origin — prevents cross-origin abuse
      allowed_origins     = var.allowed_origins
      support_credentials = false
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "node"
    # Package is zipped and mounted from blob; pre-build in CI before deploying
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    # Cosmos DB endpoint is not a secret; auth uses the managed identity
    "COSMOS_ENDPOINT"          = var.cosmos_db_endpoint
    "COSMOS_DATABASE_NAME"     = var.cosmos_db_name
    "COSMOS_CONTAINER_NAME"    = var.cosmos_container_name
  }

  # Outbound VNet integration: traffic to private endpoints resolves correctly
  virtual_network_subnet_id = var.vnet_integration_subnet_id

  tags = var.tags
}
