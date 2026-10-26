# A storage account reachable only through a private endpoint in the VNet, and only with Entra ID
# identities: shared keys and anonymous access are off.

locals {
  create_subnet   = var.existing_subnet_id == null
  create_dns_zone = var.existing_private_dns_zone_id == null
}

# --- Storage account ------------------------------------------------------------------------------

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.region
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type

  public_network_access           = "Disabled"
  shared_access_key_enabled       = false
  local_user_enabled              = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  # Keeps the account closed should public network access be turned back on, e.g. in the portal.
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    delete_retention_policy {
      days = var.soft_delete_retention_days
    }
    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  tags = var.tags

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Created through Resource Manager, so Terraform needs neither a shared key nor the private endpoint.
resource "azurerm_storage_container" "this" {
  for_each           = var.container_names
  name               = each.key
  storage_account_id = azurerm_storage_account.this.id
}

# --- Subnet ---------------------------------------------------------------------------------------

resource "azurerm_subnet" "this" {
  count                = local.create_subnet ? 1 : 0
  name                 = coalesce(var.subnet_name, "${var.name}-subnet")
  resource_group_name  = split("/", var.vnet_id)[4]
  virtual_network_name = split("/", var.vnet_id)[8]
  address_prefixes     = [var.subnet_cidr]
}

# --- Private DNS ----------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "this" {
  count               = local.create_dns_zone ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count               = local.create_dns_zone ? 1 : 0
  name                = "${var.name}-vnet"
  private_dns_zone_id = azurerm_private_dns_zone.this[0].id
  virtual_network_id  = var.vnet_id
  tags                = var.tags
}

# --- Private endpoint -----------------------------------------------------------------------------

resource "azurerm_private_endpoint" "blob" {
  name                = "${var.name}-blob"
  resource_group_name = var.resource_group_name
  location            = var.region
  subnet_id           = local.create_subnet ? azurerm_subnet.this[0].id : var.existing_subnet_id

  private_service_connection {
    name                           = "${var.name}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  # Writes the account's A record into the zone, so <name>.blob.core.windows.net resolves to the
  # endpoint's private IP inside the VNet.
  private_dns_zone_group {
    name                 = "blob"
    private_dns_zone_ids = [local.create_dns_zone ? azurerm_private_dns_zone_virtual_network_link.this[0].private_dns_zone_id : var.existing_private_dns_zone_id]
  }

  tags = var.tags
}
