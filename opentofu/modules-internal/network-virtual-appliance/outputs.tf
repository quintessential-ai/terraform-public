# The next hop of the nodes' egress. Available only once the instances exist: AKS checks the route
# when it creates a cluster, and its nodes need egress to start.
output "private_ip" {
  value = local.private_ip
  depends_on = [
    azurerm_linux_virtual_machine_scale_set.this,
  ]
}

# The source of all egress, and where the ingress ports are reached.
output "public_ip_address" {
  value = azurerm_public_ip.this.ip_address
}
