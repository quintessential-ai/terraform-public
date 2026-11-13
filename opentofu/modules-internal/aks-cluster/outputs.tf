output "id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "fqdn" {
  value = azurerm_kubernetes_cluster.this.fqdn
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "principal_id" {
  description = "Object ID of the cluster's user-assigned identity."
  value       = azurerm_user_assigned_identity.cluster.principal_id
}

output "kubelet_identity_object_id" {
  value = one(azurerm_kubernetes_cluster.this.kubelet_identity[*].object_id)
}

output "private_fqdn" {
  description = "API server FQDN, resolvable only inside the VNet. Use as --tls-server-name when tunnelling."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

output "role_assignment_ids" {
  description = "Depend on this to order work that needs cluster access to already be granted."
  value       = [for a in azurerm_role_assignment.this : a.id]
}

output "nodes_subnet_id" {
  value = azurerm_subnet.nodes.id
}

output "apiserver_subnet_id" {
  value = azurerm_subnet.apiserver.id
}
