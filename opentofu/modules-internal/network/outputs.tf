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

output "subnet_newbits" {
  value = var.subnet_newbits
}
