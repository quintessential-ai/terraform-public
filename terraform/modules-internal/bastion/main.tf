# Azure Bastion with native client tunneling: engineers run `az network bastion tunnel` to the
# private API server on 443. Standard is the lowest SKU with tunneling.
# https://learn.microsoft.com/en-us/azure/bastion/bastion-connect-to-aks-private-cluster

# Only read when the caller leaves location unset.
data "azurerm_resource_group" "this" {
  count = var.location == null ? 1 : 0
  name  = var.resource_group_name
}

locals {
  location = coalesce(var.location, one(data.azurerm_resource_group.this[*].location))
}

resource "azurerm_public_ip" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = local.location
  sku                 = "Standard"
  allocation_method   = "Static"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = local.location
  sku                 = "Standard"
  scale_units         = var.scale_units

  tunneling_enabled      = true
  ip_connect_enabled     = false
  shareable_link_enabled = false
  file_copy_enabled      = false

  ip_configuration {
    name                 = "bastion"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.this.id
  }

  tags = var.tags
}

# `az network bastion tunnel` is refused without read access to the Bastion.
resource "azurerm_role_assignment" "tunnel" {
  for_each = toset(var.tunnel_principal_ids)

  principal_id         = each.value
  principal_type       = "Group"
  role_definition_name = "Reader"
  scope                = azurerm_bastion_host.this.id
}

# --- NSGs -----------------------------------------------------------------------------------------

# Bastion may reach the API server and nothing else. The API server's load balancer forwards 443
# to 4443, and the NSG checks the backend port, so both are allowed.
resource "azurerm_network_security_group" "apiserver" {
  name                = "${var.name}-apiserver"
  resource_group_name = var.resource_group_name
  location            = local.location
  tags                = var.tags

  security_rule {
    name                       = "allow-bastion-to-apiserver"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.subnet_cidr
    source_port_range          = "*"
    destination_address_prefix = var.apiserver_subnet_cidr
    destination_port_ranges    = ["443", "4443"]
  }

  security_rule {
    name                       = "deny-bastion-other"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = var.subnet_cidr
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "apiserver" {
  subnet_id                 = var.apiserver_subnet_id
  network_security_group_id = azurerm_network_security_group.apiserver.id
}

# Without this, Bastion could tunnel to a node on any port.
resource "azurerm_network_security_group" "nodes" {
  name                = "${var.name}-nodes"
  resource_group_name = var.resource_group_name
  location            = local.location
  tags                = var.tags

  security_rule {
    name                       = "deny-bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = var.subnet_cidr
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = var.nodes_subnet_id
  network_security_group_id = azurerm_network_security_group.nodes.id
}
