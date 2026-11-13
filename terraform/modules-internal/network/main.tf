# --- Derived defaults -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

locals {
  use_existing_vnet        = var.existing_vnet_name != null
  vnet_resource_group_name = coalesce(var.existing_vnet_resource_group_name, var.resource_group_name)
}

# --- VNet -----------------------------------------------------------------------------------------

data "azurerm_virtual_network" "existing" {
  count               = local.use_existing_vnet ? 1 : 0
  name                = var.existing_vnet_name
  resource_group_name = local.vnet_resource_group_name
}

resource "azurerm_virtual_network" "this" {
  count               = local.use_existing_vnet ? 0 : 1
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.region
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

locals {
  vnet_id   = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].id : azurerm_virtual_network.this[0].id
  vnet_name = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].name : azurerm_virtual_network.this[0].name
  vnet_cidr = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].address_space[0] : var.vnet_cidr
}

# --- Peering --------------------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "outbound" {
  for_each = var.peerings

  name                         = "${local.vnet_name}-to-${each.key}"
  resource_group_name          = local.vnet_resource_group_name
  virtual_network_name         = local.vnet_name
  remote_virtual_network_id    = each.value.remote_virtual_network_id
  allow_virtual_network_access = each.value.allow_virtual_network_access
  allow_forwarded_traffic      = each.value.allow_forwarded_traffic
  allow_gateway_transit        = each.value.allow_gateway_transit
  use_remote_gateways          = each.value.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "inbound" {
  for_each = { for name, peering in var.peerings : name => peering if peering.create_reverse_peering }

  name                         = "${each.key}-to-${local.vnet_name}"
  resource_group_name          = split("/", each.value.remote_virtual_network_id)[4]
  virtual_network_name         = split("/", each.value.remote_virtual_network_id)[8]
  remote_virtual_network_id    = local.vnet_id
  allow_virtual_network_access = each.value.allow_virtual_network_access
  allow_forwarded_traffic      = each.value.allow_forwarded_traffic
  # Gateway flags mirror: whichever side transits, the other uses.
  allow_gateway_transit = each.value.use_remote_gateways
  use_remote_gateways   = each.value.allow_gateway_transit

  lifecycle {
    precondition {
      condition     = split("/", each.value.remote_virtual_network_id)[2] == data.azurerm_client_config.current.subscription_id
      error_message = "Peering \"${each.key}\" points at another subscription, but the reverse side would be created with this module's provider and target the wrong one. Set create_reverse_peering = false and create that side where the remote VNet lives."
    }
  }
}

# --- Network appliance ----------------------------------------------------------------------------

locals {
  network_appliance_vnet_resource_group_name = try(split("/", var.network_appliance_vnet_id)[4], null)
  network_appliance_vnet_name                = try(split("/", var.network_appliance_vnet_id)[8], null)
}

# A network appliance in another VNet is reached through a peering, created both ways. Replies to egress
# come back through the appliance with internet sources, so this side allows forwarded traffic.
resource "azurerm_virtual_network_peering" "to_network_appliance" {
  count                        = var.network_appliance_vnet_id == null ? 0 : 1
  name                         = "${local.vnet_name}-to-${local.network_appliance_vnet_name}"
  resource_group_name          = local.vnet_resource_group_name
  virtual_network_name         = local.vnet_name
  remote_virtual_network_id    = var.network_appliance_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "from_network_appliance" {
  provider                     = azurerm.network_appliance
  count                        = var.network_appliance_vnet_id == null ? 0 : 1
  name                         = "${local.network_appliance_vnet_name}-to-${local.vnet_name}"
  resource_group_name          = local.network_appliance_vnet_resource_group_name
  virtual_network_name         = local.network_appliance_vnet_name
  remote_virtual_network_id    = local.vnet_id
  allow_virtual_network_access = true
}
