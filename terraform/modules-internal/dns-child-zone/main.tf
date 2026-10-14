# An ordinary public zone. Delegation is what makes it a child: the parent zone answers queries for
# this zone with an NS record pointing at its name servers. Without it the zone resolves only for
# whoever is pointed at it directly.

locals {
  zone_name                       = "${var.dns_zone.prefix}.${var.dns_zone.parent_zone_name}"
  parent_zone_resource_group_name = coalesce(var.dns_parent_zone_resource_group_name, var.resource_group_name)
}

resource "azurerm_dns_zone" "child" {
  name                = local.zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

data "azurerm_dns_zone" "parent" {
  count               = var.dns_enable_delegation ? 1 : 0
  provider            = azurerm.parent
  name                = var.dns_zone.parent_zone_name
  resource_group_name = local.parent_zone_resource_group_name
}

resource "azurerm_dns_ns_record" "delegation" {
  count               = var.dns_enable_delegation ? 1 : 0
  provider            = azurerm.parent
  name                = var.dns_zone.prefix
  zone_name           = data.azurerm_dns_zone.parent[0].name
  resource_group_name = local.parent_zone_resource_group_name
  ttl                 = var.ns_record_ttl
  records             = tolist(azurerm_dns_zone.child.name_servers)
  tags                = var.tags
}
