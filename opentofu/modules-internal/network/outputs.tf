output "vnet_id" {
  value = local.vnet_id
}

output "vnet_name" {
  value = local.vnet_name
}

output "vnet_cidr" {
  value = local.vnet_cidr
}

output "nodes_subnet_id" {
  value = azurerm_subnet.nodes.id
}

output "nodes_subnet_cidr" {
  description = "The range actually used, whether supplied or derived."
  value       = local.nodes_subnet_cidr
}

output "apiserver_subnet_id" {
  value = azurerm_subnet.apiserver.id
}

output "apiserver_subnet_cidr" {
  value = local.apiserver_subnet_cidr
}

output "bastion_subnet_id" {
  value = try(azurerm_subnet.bastion[0].id, null)
}

output "bastion_subnet_cidr" {
  value = var.create_bastion_subnet ? local.bastion_subnet_cidr : null
}

output "ingress_lb_subnet_cidr" {
  value = var.route_egress_to_network_appliance ? local.ingress_lb_subnet_cidr : null
}

# Ready only once the nodes subnet uses it and the gateway's load balancer subnet exists. A cluster
# reading it is created after both and destroyed before them, while its load balancer still holds
# an IP in that subnet.
output "route_table_id" {
  value = try(azurerm_route_table.egress[0].id, null)
  depends_on = [
    azurerm_subnet_route_table_association.nodes,
    azurerm_subnet.ingress_lb,
  ]
}

# Ready only once the nodes subnet uses it and it has its public IP: AKS checks both when it
# creates a cluster with userAssignedNATGateway.
output "nat_gateway_id" {
  value = try(azurerm_nat_gateway.this[0].id, null)
  depends_on = [
    azurerm_subnet_nat_gateway_association.nodes,
    azurerm_nat_gateway_public_ip_association.this,
  ]
}

output "egress_public_ip_address" {
  value = try(azurerm_public_ip.nat[0].ip_address, null)
}

output "subnet_newbits" {
  value = var.subnet_newbits
}
