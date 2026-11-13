output "vnet_id" {
  value = local.vnet_id
}

output "vnet_name" {
  value = local.vnet_name
}

output "vnet_cidr" {
  value = local.vnet_cidr
}

# Available only once the appliance is reachable from this VNet: AKS checks the route to it when it
# creates a cluster, and its nodes need egress to start.
output "network_appliance_ip" {
  value = var.network_appliance_ip
  depends_on = [
    azurerm_virtual_network_peering.to_network_appliance,
    azurerm_virtual_network_peering.from_network_appliance,
  ]
}
