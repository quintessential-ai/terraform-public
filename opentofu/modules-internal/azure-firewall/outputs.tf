# The next hop of the nodes' egress. Available only once the rules exist: AKS checks the route when
# it creates a cluster, and its nodes need egress to start.
output "private_ip" {
  value = one(azurerm_firewall.this.ip_configuration[*].private_ip_address)
  depends_on = [
    azurerm_firewall_policy_rule_collection_group.this,
  ]
}

# The source of all egress, and where the ingress ports are reached.
output "public_ip_address" {
  value = azurerm_public_ip.this.ip_address
}
