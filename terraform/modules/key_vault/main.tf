resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.suffix}-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # RBAC authorization — role assignments instead of legacy access policies
  enable_rbac_authorization = true

  # Protects against accidental destroy; set to true and 90 days for production
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  # No public internet access; accessible only via the private endpoint
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = var.tags
}

# ── Private Endpoint ─────────────────────────────────────────────────────────
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv-${var.suffix}"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-group"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}

# ── RBAC ─────────────────────────────────────────────────────────────────────
# The Terraform service principal needs admin rights so it can manage secrets
# from the deployment pipeline (e.g. rotating rotation).
resource "azurerm_role_assignment" "deployer_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.deployer_object_id
}
