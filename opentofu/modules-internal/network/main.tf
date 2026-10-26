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

# --- Subnets --------------------------------------------------------------------------------------

locals {
  # A ternary rather than coalesce(): coalesce evaluates both arguments, so an existing-VNet
  # caller supplying nodes_subnet_cidr would still have to supply a vnet_cidr that divides cleanly.
  nodes_subnet_cidr     = var.nodes_subnet_cidr != null ? var.nodes_subnet_cidr : cidrsubnet(var.vnet_cidr, var.subnet_newbits, 0)
  apiserver_subnet_cidr = var.apiserver_subnet_cidr != null ? var.apiserver_subnet_cidr : cidrsubnet(var.vnet_cidr, var.subnet_newbits, 1)
  bastion_subnet_cidr   = var.bastion_subnet_cidr != null ? var.bastion_subnet_cidr : cidrsubnet(var.vnet_cidr, var.subnet_newbits, 2)
  # Blocks 3 and 4 are the recipe's PostgreSQL and blob storage private endpoint subnets.
  ingress_lb_subnet_cidr = var.ingress_lb_subnet_cidr != null ? var.ingress_lb_subnet_cidr : cidrsubnet(var.vnet_cidr, var.subnet_newbits, 5)
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

# Holds the gateway's internal load balancer behind a network appliance. Kept apart from the nodes so a
# scaling node pool cannot take its fixed IP.
resource "azurerm_subnet" "ingress_lb" {
  count                = var.route_egress_to_network_appliance ? 1 : 0
  name                 = "aks-ingress-lb"
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [local.ingress_lb_subnet_cidr]
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

# --- Egress routing -------------------------------------------------------------------------------

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

# Without a network appliance, egress leaves through a NAT gateway on the nodes subnet.
resource "azurerm_public_ip" "nat" {
  count               = var.route_egress_to_network_appliance ? 0 : 1
  name                = "${local.vnet_name}-nat"
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "Standard"
  allocation_method   = "Static"
  tags                = var.tags

  # The cluster's egress address, which others allow-list: a recreated IP gets a new address.
  lifecycle {
    prevent_destroy = true
  }
}

# A Standard NAT gateway sits in one zone at most. Without zones, Azure picks where it runs.
resource "azurerm_nat_gateway" "this" {
  count               = var.route_egress_to_network_appliance ? 0 : 1
  name                = "${local.vnet_name}-nat"
  resource_group_name = var.resource_group_name
  location            = var.region
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count                = var.route_egress_to_network_appliance ? 0 : 1
  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "nodes" {
  count          = var.route_egress_to_network_appliance ? 0 : 1
  subnet_id      = azurerm_subnet.nodes.id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}

# Sends all egress from the nodes to the network appliance. AKS checks this route when it creates a
# cluster with userDefinedRouting, which only takes an appliance or a VNet gateway as its next hop,
# and its nodes need the appliance reachable to start.
resource "azurerm_route_table" "egress" {
  count               = var.route_egress_to_network_appliance ? 1 : 0
  name                = "${local.vnet_name}-egress"
  resource_group_name = var.resource_group_name
  location            = var.region
  tags                = var.tags

  route {
    name                   = "default-to-network-appliance"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.network_appliance_ip
  }

  depends_on = [
    azurerm_virtual_network_peering.to_network_appliance,
    azurerm_virtual_network_peering.from_network_appliance,
  ]
}

resource "azurerm_subnet_route_table_association" "nodes" {
  count          = var.route_egress_to_network_appliance ? 1 : 0
  subnet_id      = azurerm_subnet.nodes.id
  route_table_id = azurerm_route_table.egress[0].id
}
