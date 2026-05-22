resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-${var.suffix}-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  # All traffic must arrive via the private endpoint; no public internet access
  public_network_access_enabled = false

  # Disable key/connection-string auth; callers must authenticate via Entra ID.
  # The Function App's managed identity is granted a built-in SQL RBAC role instead.
  local_authentication_disabled = true

  consistency_policy {
    # Session consistency: strong read-your-writes within a session, low latency globally
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "EmployeeDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "employees" {
  name                = "Employees"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  # Partition on department so queries scoped to a department are single-partition
  partition_key_path = "/department"
  throughput         = var.throughput

  indexing_policy {
    indexing_mode = "consistent"
    included_path { path = "/*" }
    excluded_path { path = "/\"_etag\"/?" }
  }
}

# ── Private Endpoint ─────────────────────────────────────────────────────────
resource "azurerm_private_endpoint" "cosmos" {
  name                = "pe-cosmos-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-cosmos-${var.suffix}"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "cosmos-dns-group"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
