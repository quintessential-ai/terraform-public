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

# The source of all egress and where HTTPS comes in, when Terraform creates the network appliance.
output "network_appliance_public_ip_address" {
  value = local.outputs.network_appliance_public_ip_address
}

# The target of the network appliance's DNAT rule, and the gateway Service's IP.
output "ingress_lb_private_ip" {
  value = local.outputs.ingress_lb_private_ip
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
  value = local.outputs.neo4j_backup_identity_client_id
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
