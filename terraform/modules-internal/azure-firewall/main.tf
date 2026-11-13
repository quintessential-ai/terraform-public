# An Azure Firewall that forwards the nodes' egress to the internet and the ingress ports of its
# public IP to the gateway. Both leave translated to the firewall's addresses.

locals {
  vnet_resource_group_name = split("/", var.vnet_id)[4]
  vnet_name                = split("/", var.vnet_id)[8]
  subnet_prefix_length     = tonumber(split("/", var.subnet_cidr)[1])

  # The Basic tier sends its management traffic through a NIC of its own.
  needs_management = var.sku_tier == "Basic"
}

# --- Subnets --------------------------------------------------------------------------------------

# Azure requires these names, and a /26 for each.
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [cidrsubnet(var.subnet_cidr, 26 - local.subnet_prefix_length, 0)]
}

resource "azurerm_subnet" "management" {
  count                = local.needs_management ? 1 : 0
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [cidrsubnet(var.subnet_cidr, 26 - local.subnet_prefix_length, 1)]
}

# --- Public IPs -----------------------------------------------------------------------------------

resource "azurerm_public_ip" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = var.availability_zones
  tags                = var.tags
}

resource "azurerm_public_ip" "management" {
  count               = local.needs_management ? 1 : 0
  name                = "${var.name}-management"
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = var.availability_zones
  tags                = var.tags
}

# --- Policy ---------------------------------------------------------------------------------------

resource "azurerm_firewall_policy" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = var.sku_tier
  tags                = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "complexio"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  # DNAT also translates the source to the firewall's address, so replies come back through it.
  nat_rule_collection {
    name     = "ingress"
    priority = 100
    action   = "Dnat"

    dynamic "rule" {
      for_each = var.ingress_ports
      content {
        name                = "ingress-${rule.value}"
        protocols           = ["TCP"]
        source_addresses    = ["*"]
        destination_address = azurerm_public_ip.this.ip_address
        destination_ports   = [tostring(rule.value)]
        translated_address  = var.ingress_target_ip
        translated_port     = rule.value
      }
    }
  }

  network_rule_collection {
    name     = "egress"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "all"
      protocols             = ["Any"]
      source_addresses      = var.egress_source_cidrs
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }

  # Kept, with the firewall, until the route points at another appliance. See the firewall.
  lifecycle {
    create_before_destroy = true
  }
}

# --- Firewall -------------------------------------------------------------------------------------

resource "azurerm_firewall" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku_name            = "AZFW_VNet"
  sku_tier            = var.sku_tier
  firewall_policy_id  = azurerm_firewall_policy.this.id
  zones               = var.availability_zones
  tags                = var.tags

  ip_configuration {
    name                 = "public"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.this.id
  }

  dynamic "management_ip_configuration" {
    for_each = local.needs_management ? [0] : []
    content {
      name                 = "management"
      subnet_id            = azurerm_subnet.management[0].id
      public_ip_address_id = azurerm_public_ip.management[0].id
    }
  }

  # When the recipe switches to another appliance, Terraform destroys this one only after the route
  # points at the new one. Terraform extends it to every resource the firewall and the rule
  # collection group depend on, which is the whole module.
  lifecycle {
    create_before_destroy = true
  }
}
