output "subscription_id" {
  value = local.outputs.subscription_id
}

output "resource_group_name" {
  value = local.outputs.resource_group_name
}

output "tenant_id" {
  value = local.outputs.tenant_id
}

output "cluster_name" {
  value = local.outputs.cluster_name
}

output "cluster_id" {
  value = local.outputs.cluster_id
}

output "oidc_issuer_url" {
  value = local.outputs.oidc_issuer_url
}

# For kubectl through a tunnel: the kubeconfig's --tls-server-name.
output "private_fqdn" {
  value = local.outputs.private_fqdn
}

output "bastion_name" {
  value = local.outputs.bastion_name
}

output "node_resource_group" {
  value = local.outputs.node_resource_group
}

output "vnet_id" {
  value = local.outputs.vnet_id
}

output "nodes_subnet_cidr" {
  value = local.outputs.nodes_subnet_cidr
}

# Without an existing network appliance: the NAT gateway's IP, the source of all egress.
output "egress_public_ip_address" {
  value = local.outputs.egress_public_ip_address
}

# Behind an existing network appliance: the target of its DNAT rule, and the gateway Service's IP.
output "ingress_lb_private_ip" {
  value = local.outputs.ingress_lb_private_ip
}

# For the gateway's GatewayParameters: service.beta.kubernetes.io/azure-pip-name and
# service.beta.kubernetes.io/azure-load-balancer-resource-group.

output "gateway_public_ip_name" {
  value = local.outputs.gateway_public_ip_name
}

output "gateway_public_ip_address" {
  value = local.outputs.gateway_public_ip_address
}

# The vault the Postgres and the Entra app registrations' credentials are written to.
output "key_vault_id" {
  value = local.outputs.key_vault_id
}

output "key_vault_name" {
  value = local.outputs.key_vault_name
}

# Client IDs for the azure.workload.identity/client-id ServiceAccount annotations.

output "external_secrets_identity_client_id" {
  value = local.outputs.external_secrets_identity_client_id
}

output "inference_worker_identity_client_ids" {
  description = "Keyed by Kubernetes namespace."
  value       = local.outputs.inference_worker_identity_client_ids
}

output "external_dns_identity_client_id" {
  value = local.outputs.external_dns_identity_client_id
}

output "cert_manager_identity_client_id" {
  value = local.outputs.cert_manager_identity_client_id
}

output "s3proxy_identity_client_id" {
  value = local.outputs.s3proxy_identity_client_id
}

output "neo4j_backup_identity_client_id" {
  value = try(module.workload_identity["neo4j-backup"].client_id, null)
}

output "postgres_fqdn" {
  value = local.outputs.postgres_fqdn
}

# For the s3proxy chart's backend.azureBlobStorage.accountName.
output "blob_storage_account_name" {
  value = local.outputs.blob_storage_account_name
}

output "blob_storage_container_names" {
  value = local.outputs.blob_storage_container_names
}

output "child_dns_zone_name" {
  value = local.outputs.child_dns_zone_name
}

output "child_dns_zone_name_servers" {
  value = local.outputs.child_dns_zone_name_servers
}
