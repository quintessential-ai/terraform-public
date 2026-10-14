output "subscription_id" {
  value = local.subscription_id
}

output "resource_group_name" {
  value = local.resource_group_name
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "cluster_name" {
  value = module.cluster.name
}

output "cluster_id" {
  value = module.cluster.id
}

output "oidc_issuer_url" {
  value = module.cluster.oidc_issuer_url
}

# For kubectl through a tunnel: the kubeconfig's --tls-server-name.
output "private_fqdn" {
  value = module.cluster.private_fqdn
}

output "bastion_name" {
  value = try(module.bastion[0].name, null)
}

output "node_resource_group" {
  value = module.cluster.node_resource_group
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "nodes_subnet_cidr" {
  value = module.network.nodes_subnet_cidr
}

# For the gateway's GatewayParameters: service.beta.kubernetes.io/azure-pip-name and
# service.beta.kubernetes.io/azure-load-balancer-resource-group.

output "gateway_public_ip_name" {
  value = module.cluster.gateway_public_ip_name
}

output "gateway_public_ip_address" {
  value = module.cluster.gateway_public_ip_address
}

output "key_vault_ids" {
  value = local.key_vault_ids
}

# Client IDs for the azure.workload.identity/client-id ServiceAccount annotations.

output "external_secrets_identity_client_id" {
  value = module.workload_identity["external-secrets"].client_id
}

output "inference_worker_identity_client_ids" {
  description = "Keyed by Kubernetes namespace."
  value       = { for ns in var.k8s_namespaces : ns => module.workload_identity["inference-worker/${ns}"].client_id }
}

output "external_dns_identity_client_id" {
  value = try(module.workload_identity["external-dns"].client_id, null)
}

output "cert_manager_identity_client_id" {
  value = try(module.workload_identity["cert-manager"].client_id, null)
}

output "postgres_fqdn" {
  value = try(module.postgres[0].fqdn, null)
}

output "child_dns_zone_name" {
  value = try(module.dns_child_zone[0].name, null)
}

output "child_dns_zone_name_servers" {
  value = try(module.dns_child_zone[0].name_servers, null)
}
