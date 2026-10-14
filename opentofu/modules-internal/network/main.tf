# --- Derived defaults -----------------------------------------------------------------------------

# Only read when the caller leaves location unset.
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  count = var.location == null ? 1 : 0
  name  = var.resource_group_name
}

locals {
  location                 = coalesce(var.location, one(data.azurerm_resource_group.this[*].location))
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
  location            = local.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

locals {
  vnet_id   = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].id : azurerm_virtual_network.this[0].id
  vnet_name = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].name : azurerm_virtual_network.this[0].name
  vnet_cidr = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].address_space[0] : var.vnet_cidr
}

# --- Subnets --------------------------------------------------------------------------------------

locals {
  # A ternary rather than coalesce(): coalesce evaluates both arguments, so an existing-VNet
  # caller supplying nodes_subnet_cidr would still have to supply a vnet_cidr that divides cleanly.
  nodes_subnet_cidr     = var.nodes_subnet_cidr != null ? var.nodes_subnet_cidr : cidrsubnet(var.vnet_cidr, var.subnet_newbits, 0)
  apiserver_subnet_cidr = var.apiserver_subnet_cidr != null ? var.apiserver_subnet_cidr : cidrsubnet(var.vnet_cidr, var.subnet_newbits, 1)
  bastion_subnet_cidr   = var.bastion_subnet_cidr != null ? var.bastion_subnet_cidr : cidrsubnet(var.vnet_cidr, var.subnet_newbits, 2)
}

# Subnets live in the VNet's resource group, which may differ from the cluster's.
resource "azurerm_subnet" "nodes" {
  name                 = var.nodes_subnet_name
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [local.nodes_subnet_cidr]

  lifecycle {
    precondition {
      condition     = tonumber(split("/", local.nodes_subnet_cidr)[1]) <= 24
      error_message = "The nodes subnet must be at least a /24."
    }
  }
}

# Holds the private API server's load balancer and instances.
# https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration
resource "azurerm_subnet" "apiserver" {
  name                 = var.apiserver_subnet_name
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [local.apiserver_subnet_cidr]

  delegation {
    name = "aks"
    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  lifecycle {
    precondition {
      condition     = tonumber(split("/", local.apiserver_subnet_cidr)[1]) <= 27
      error_message = "The API server subnet must be at least a /27."
    }
  }
}

# Azure Bastion requires this exact name and at least a /26.
resource "azurerm_subnet" "bastion" {
  count                = var.create_bastion_subnet ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [local.bastion_subnet_cidr]

  lifecycle {
    precondition {
      condition     = tonumber(split("/", local.bastion_subnet_cidr)[1]) <= 26
      error_message = "The Bastion subnet must be at least a /26."
    }
  }
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
