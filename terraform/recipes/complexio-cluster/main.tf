data "azurerm_client_config" "current" {}

locals {
  subscription_id = data.azurerm_client_config.current.subscription_id
}

# --- Resource group -----------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  count    = var.resource_group_name == null ? 0 : 1
  name     = var.resource_group_name
  location = var.region
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.existing_resource_group_name == null ? 0 : 1
  name  = var.existing_resource_group_name
}

locals {
  # Referencing the resource/data source rather than the variable keeps the dependency edges.
  resource_group_name = var.resource_group_name == null ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.this[0].name
}

# --- Networking ---------------------------------------------------------------------------------

module "network" {
  source = "../../modules-internal/network"

  providers = {
    azurerm                   = azurerm
    azurerm.network_appliance = azurerm.network_appliance
  }

  vnet_name           = var.cluster_name
  resource_group_name = local.resource_group_name
  region              = var.region

  existing_vnet_name                = var.existing_vnet_name
  existing_vnet_resource_group_name = var.existing_vnet_resource_group_name
  vnet_cidr                         = var.vnet_cidr
  nodes_subnet_cidr                 = var.nodes_subnet_cidr
  apiserver_subnet_cidr             = var.apiserver_subnet_cidr
  bastion_subnet_cidr               = var.bastion_subnet_cidr
  ingress_lb_subnet_cidr            = var.ingress_lb_subnet_cidr
  peerings                          = var.vnet_peerings
  create_bastion_subnet             = var.create_bastion
  route_egress_to_network_appliance = var.use_existing_network_appliance
  network_appliance_ip              = var.use_existing_network_appliance ? var.existing_network_appliance_private_ip : null
  network_appliance_vnet_id         = var.use_existing_network_appliance ? var.existing_network_appliance_vnet_id : null

  tags = var.tags
}

# --- Cluster ------------------------------------------------------------------------------------

locals {
  # Fixed so the existing network appliance's DNAT rule and the gateway's Service agree on it. Azure
  # reserves the first four addresses of every subnet.
  ingress_lb_private_ip = var.use_existing_network_appliance ? cidrhost(module.network.ingress_lb_subnet_cidr, 4) : null
  # Behind an existing network appliance the gateway has only a private IP.
  create_gateway_public_ip = var.create_gateway_public_ip && !var.use_existing_network_appliance
}

locals {
  acr_id_prefix = "/providers/Microsoft.ContainerRegistry/registries"

  docker_acr_ids = { for r in var.docker_acr_registries :
    "${r.resource_group_name}/${r.name}" => "/subscriptions/${r.subscription_id}/resourceGroups/${r.resource_group_name}${local.acr_id_prefix}/${r.name}"
  }
  generic_acr_ids = { for r in var.generic_acr_registries :
    "${r.resource_group_name}/${r.name}" => "/subscriptions/${r.subscription_id}/resourceGroups/${r.resource_group_name}${local.acr_id_prefix}/${r.name}"
  }
}

module "cluster" {
  source = "../../modules-internal/aks-cluster"

  cluster_name        = var.cluster_name
  region              = var.region
  resource_group_name = local.resource_group_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.managed_cluster_sku_tier

  private_cluster_enabled = var.private_cluster_enabled

  nodes_subnet_id     = module.network.nodes_subnet_id
  apiserver_subnet_id = module.network.apiserver_subnet_id
  vnet_id             = module.network.vnet_id

  availability_zones        = var.availability_zones
  core_pool_vm_size         = var.core_worker_pool_vm_size
  core_pool_os_disk_size_gb = var.core_worker_pool_os_disk_size

  azure_rbac_enabled = var.azure_rbac.enabled
  principal_ids = var.azure_rbac.enabled ? {
    cluster_admin = var.azure_rbac.cluster_admin_principal_ids
    admin         = var.azure_rbac.admin_principal_ids
    writer        = var.azure_rbac.writer_principal_ids
    reader        = var.azure_rbac.reader_principal_ids
  } : {}
  node_provisioning_mode         = var.node_provisioning_mode
  enable_azure_container_storage = var.enable_azure_container_storage
  acr_ids                        = local.docker_acr_ids
  create_gateway_public_ip       = local.create_gateway_public_ip
  outbound_type                  = var.use_existing_network_appliance ? "userDefinedRouting" : "userAssignedNATGateway"
  nat_gateway_id                 = module.network.nat_gateway_id
  route_table_id                 = module.network.route_table_id

  tags = var.tags
}

# --- Bastion ------------------------------------------------------------------------------------

module "bastion" {
  source = "../../modules-internal/bastion"
  count  = var.create_bastion ? 1 : 0

  name                = "${var.cluster_name}-bastion"
  resource_group_name = local.resource_group_name
  region              = var.region
  subnet_id           = module.network.bastion_subnet_id
  subnet_cidr         = module.network.bastion_subnet_cidr

  apiserver_subnet_id   = module.network.apiserver_subnet_id
  apiserver_subnet_cidr = module.network.apiserver_subnet_cidr
  nodes_subnet_id       = module.network.nodes_subnet_id
  gateway_public_ip     = local.create_gateway_public_ip ? { address = module.cluster.gateway_public_ip_address } : null

  # Only cluster admins may tunnel in.
  tunnel_principal_ids = var.azure_rbac.enabled ? var.azure_rbac.cluster_admin_principal_ids : []

  tags = var.tags
}

# --- Key Vault ----------------------------------------------------------------------------------

resource "random_string" "key_vault_suffix" {
  length  = 8
  special = false
  upper   = false
}

# The only Key Vault Complexio uses: the Postgres credentials and the Entra app registrations'
# credentials are written here, and ExternalSecrets reads them.
#
# Reachable from any network: Terraform and the engineers who update secrets run from changing IPs.
# Access is granted only through RBAC.
#trivy:ignore:AZU-0013
resource "azurerm_key_vault" "this" {
  # Ensure the Key Vault name does not exceed 24 characters, as required by Azure. When the name is directly set, we already have a
  # variable validation. When it's autogenerated, it enforces the prefix is short enough to keep the total length within 24 characters.
  name                       = coalesce(var.azure_key_vault_name, "${trimsuffix(substr(var.cluster_name, 0, 15), "-")}-${random_string.key_vault_suffix.result}")
  resource_group_name        = local.resource_group_name
  location                   = var.region
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true

  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  enabled_for_disk_encryption     = true

  tags = var.tags
}

resource "azurerm_role_assignment" "key_vault_admins" {
  # Keyed as before the vault became unconditional, so existing assignments keep their addresses.
  for_each = { for id in var.azure_rbac.cluster_admin_principal_ids : "${id}-Key Vault Administrator" => id }

  principal_id         = each.value
  principal_type       = "Group"
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.this.id
}

# The vault authorizes data-plane access through RBAC alone, so whoever runs Terraform needs a role
# on it to manage `azurerm_key_vault_secret` and `azurerm_key_vault_certificate` resources: this
# recipe writes the Postgres credentials, and entra-app-registrations writes secrets and
# certificates. The grants target fixed principals rather than the caller's identity, so we get the
# same result regardless of who applied last.
resource "azurerm_role_assignment" "key_vault_secrets_officers" {
  for_each = toset(var.key_vault_secrets_officer_groups)

  principal_id         = each.value
  role_definition_name = "Key Vault Secrets Officer"
  scope                = azurerm_key_vault.this.id
}

resource "azurerm_role_assignment" "key_vault_certificates_officers" {
  for_each = toset(var.key_vault_secrets_officer_groups)

  principal_id         = each.value
  role_definition_name = "Key Vault Certificates Officer"
  scope                = azurerm_key_vault.this.id
}

# The vault's ID, available only once every grant on it exists. Any secret written to the Key Vault
# should depend on this resource to ensure the entity running Terraform got the grant.
resource "terraform_data" "key_vault_id_after_grants" {
  input = azurerm_key_vault.this.id

  depends_on = [
    azurerm_role_assignment.key_vault_admins,
    azurerm_role_assignment.key_vault_secrets_officers,
    azurerm_role_assignment.key_vault_certificates_officers,
  ]
}

resource "random_string" "postgres_suffix" {
  count   = var.create_postgres ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# --- PostgreSQL ----------------------------------------------------------------------------------

module "postgres" {
  source = "../../modules-internal/postgres-flexible-server"
  count  = var.create_postgres ? 1 : 0

  # Server names are lowercase and at most 63 characters. A set name is checked by the variable's
  # validation; a generated one trims the cluster name so the whole stays within the limit.
  name                = coalesce(var.postgres_name, "${trimsuffix(substr(lower(var.cluster_name), 0, 51), "-")}-pg-${random_string.postgres_suffix[0].result}")
  resource_group_name = local.resource_group_name
  region              = var.region

  vnet_id                      = module.network.vnet_id
  subnet_cidr                  = var.postgres_subnet_cidr != null ? var.postgres_subnet_cidr : cidrsubnet(module.network.vnet_cidr, module.network.subnet_newbits, 3)
  existing_private_dns_zone_id = var.postgres_existing_private_dns_zone_id

  postgres_version = var.postgres_version
  sku_name         = var.postgres_sku_name
  zone             = var.postgres_zone
  storage = {
    size_mb         = var.postgres_storage_size_mb
    iops            = var.postgres_storage_iops
    throughput_mbps = var.postgres_storage_throughput_mbps
  }
  backup_retention_days = var.postgres_backup_retention_days
  maintenance_window    = var.postgres_maintenance_window
  server_parameters     = var.postgres_server_parameters
  pgbouncer_parameters  = var.postgres_pgbouncer_parameters
  extensions            = var.postgres_extensions

  administrator_login            = var.postgres_administrator_login
  administrator_password         = var.postgres_administrator_password
  administrator_password_version = var.postgres_administrator_password_version

  # Read through terraform_data, rather than from the vault, so the secrets wait for the grants. A
  # module-level depends_on would also defer every data source inside the module.
  key_vault_id = terraform_data.key_vault_id_after_grants.output

  tags = var.tags
}

# --- Blob storage -------------------------------------------------------------------------------

locals {
  # Created with the account, for clients that never create their bucket, such as ClickHouse's S3
  # disk. The others are created through S3Proxy on first use.
  default_containers = ["clickhouse"]
}

resource "random_string" "blob_storage_suffix" {
  count   = var.create_blob_storage ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

module "blob_storage" {
  source = "../../modules-internal/blob-storage"
  count  = var.create_blob_storage ? 1 : 0

  # Account names are 3 to 24 lowercase letters and digits. A set name is checked by the variable's
  # validation; a generated one strips the cluster name down to those characters and trims it.
  name                = coalesce(var.blob_storage_account_name, "${substr(replace(lower(var.cluster_name), "/[^a-z0-9]/", ""), 0, 16)}${random_string.blob_storage_suffix[0].result}")
  resource_group_name = local.resource_group_name
  region              = var.region

  vnet_id                      = module.network.vnet_id
  subnet_cidr                  = var.blob_storage_subnet_cidr != null ? var.blob_storage_subnet_cidr : cidrsubnet(module.network.vnet_cidr, module.network.subnet_newbits, 4)
  existing_private_dns_zone_id = var.blob_storage_existing_private_dns_zone_id

  replication_type           = var.blob_storage_replication_type
  soft_delete_retention_days = var.blob_storage_soft_delete_retention_days
  container_names            = local.default_containers

  tags = var.tags
}

# --- DNS ----------------------------------------------------------------------------------------

module "dns_child_zone" {
  source = "../../modules-internal/dns-child-zone"
  count  = var.dns_zone == null ? 0 : 1

  providers = { azurerm.parent = azurerm.parent_dns }

  resource_group_name                 = local.resource_group_name
  dns_zone                            = var.dns_zone
  dns_enable_delegation               = var.dns_enable_delegation
  dns_parent_zone_resource_group_name = var.dns_parent_zone_resource_group_name
  tags                                = var.tags
}

# --- Workload identities ------------------------------------------------------------------------

# Every ServiceAccount that needs to reach Azure, and what it is allowed to do there. The client ID
# of each goes on the ServiceAccount as the azure.workload.identity/client-id annotation.
locals {
  workload_identities = merge(
    {
      "external-secrets" = {
        namespace            = "external-secrets"
        service_account_name = "external-secrets"
        role_assignments = {
          keyvault = { role_definition_name = "Key Vault Secrets User", scope = azurerm_key_vault.this.id }
        }
      }
    },

    # external-dns writes records; cert-manager writes the TXT records for DNS-01 challenges.
    var.dns_zone == null ? {} : { for name in ["external-dns", "cert-manager"] : name => {
      namespace            = name
      service_account_name = name
      role_assignments = {
        child-zone = { role_definition_name = "DNS Zone Contributor", scope = module.dns_child_zone[0].id }
      }
    } },

    # One per Complexio installation: pulls model artifacts from the generic registries.
    { for ns in var.k8s_namespaces : "inference-worker/${ns}" => {
      namespace            = ns
      service_account_name = "inference-worker"
      role_assignments = { for label, id in local.generic_acr_ids :
        "acr-${label}" => { role_definition_name = "AcrPull", scope = id }
      }
    } },

    # One S3Proxy serves every Complexio installation. Granted on the account, not on containers:
    # clients create their buckets through it on first use.
    var.create_blob_storage ? {
      "s3proxy" = {
        namespace            = "s3proxy"
        service_account_name = "s3proxy"
        role_assignments = {
          blob-storage = { role_definition_name = "Storage Blob Data Contributor", scope = module.blob_storage[0].id }
        }
      }
    } : {},
  )
}

module "workload_identity" {
  source   = "../../modules-internal/workload-identity"
  for_each = local.workload_identities

  name_prefix         = module.cluster.name
  resource_group_name = local.resource_group_name
  region              = var.region
  oidc_issuer_url     = module.cluster.oidc_issuer_url
  tags                = var.tags

  namespace            = each.value.namespace
  service_account_name = each.value.service_account_name
  role_assignments     = each.value.role_assignments
}
