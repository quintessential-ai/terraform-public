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
  resource_group_id   = var.resource_group_name == null ? data.azurerm_resource_group.existing[0].id : azurerm_resource_group.this[0].id
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

  principal_ids = {
    cluster_admin = var.azure_rbac.cluster_admin_principal_ids
    admin         = var.azure_rbac.admin_principal_ids
    writer        = var.azure_rbac.writer_principal_ids
    reader        = var.azure_rbac.reader_principal_ids
  }
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
  tunnel_principal_ids = var.azure_rbac.cluster_admin_principal_ids

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
  # disk and the Neo4j backup job. The others are created through S3Proxy on first use.
  default_containers = ["clickhouse", "neo4j-backups"]
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

# DNS Zone Contributor would also let these identities delete the zone and write NS, MX, SRV, CAA
# and the other record types, which neither needs. external-dns writes A, AAAA and CNAME records
# plus the TXT records that mark them as its own; cert-manager writes only the DNS-01 TXT records.
# https://learn.microsoft.com/en-us/azure/role-based-access-control/permissions/networking#microsoftnetwork
locals {
  dns_record_writers = var.dns_zone == null ? {} : {
    "external-dns" = ["A", "AAAA", "CNAME", "TXT"]
    "cert-manager" = ["TXT"]
  }
}

resource "random_string" "dns_record_writer_suffix" {
  count   = var.dns_zone == null ? 0 : 1
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_role_definition" "dns_record_writer" {
  for_each = local.dns_record_writers

  # Custom role names are unique per tenant, but the zone name isn't: an undelegated zone can share
  # its name with zones in other resource groups.
  name        = "${each.key} records in ${module.dns_child_zone[0].name} ${random_string.dns_record_writer_suffix[0].result}"
  description = "Writes ${join(", ", each.value)} records in ${module.dns_child_zone[0].name}."
  # Custom roles cannot be assignable at a single resource; the assignment below narrows it to the zone.
  scope             = local.resource_group_id
  assignable_scopes = [local.resource_group_id]

  permissions {
    actions = concat(
      [
        "Microsoft.Network/dnsZones/read",
        "Microsoft.Network/dnsZones/all/read",
        "Microsoft.Network/dnsZones/recordsets/read",
      ],
      flatten([for type in each.value : [
        "Microsoft.Network/dnsZones/${type}/read",
        "Microsoft.Network/dnsZones/${type}/write",
        "Microsoft.Network/dnsZones/${type}/delete",
      ]]),
    )
  }
}

# --- Workload identities ------------------------------------------------------------------------

# Every ServiceAccount that needs to reach Azure, and what it is allowed to do there. The client ID
# of each goes on the ServiceAccount as the azure.workload.identity/client-id annotation.
locals {
  workload_identities = merge(
    {
      # The ServiceAccount the customer's ClusterSecretStore authenticates with. Complexio's vault has
      # its own, federated to an identity in Complexio's tenant.
      "external-secrets" = {
        namespace            = "external-secrets"
        service_account_name = "customer-key-vault"
        role_assignments = {
          keyvault = { role_definition_name = "Key Vault Secrets User", scope = azurerm_key_vault.this.id }
        }
      }
    },

    # ExternalDNS and CertManager
    { for name, role in azurerm_role_definition.dns_record_writer : name => {
      namespace            = name
      service_account_name = name
      role_assignments = {
        child-zone = { role_definition_id = role.role_definition_resource_id, scope = module.dns_child_zone[0].id }
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

    # The Neo4j backup CronJob uploads straight to Blob, not through S3Proxy, so only its container.
    var.create_blob_storage ? {
      "neo4j-backup" = {
        namespace            = "complexio-neo4j-prod"
        service_account_name = "neo4j-backup"
        role_assignments = {
          neo4j-backups = { role_definition_name = "Storage Blob Data Contributor", scope = module.blob_storage[0].container_ids["neo4j-backups"] }
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

# --- Bootstrap ----------------------------------------------------------------------------------

locals {
  # Where external_key_vault lives.
  complexio_tenant_id = "656df794-d495-4d85-872f-6ca46c6b0e52"

  # Vault names are case-insensitive, and the bootstrap module takes the lowercase URL.
  external_key_vault_url = "https://${lower(var.external_key_vault.name)}.vault.azure.net/"

  oci_source_artifact_url  = "oci://complexio.azurecr.io/deployments/${var.customer_name}"
  oci_source_artifact_tag  = "latest"
  oci_source_artifact_path = "clusters/${var.customer_name}"
}
module "bootstrap" {
  source = "../../modules-internal/cluster-bootstrap"

  cluster = {
    id                  = module.cluster.id
    name                = module.cluster.name
    resource_group_name = local.resource_group_name
    subscription_id     = local.subscription_id
  }
  cluster_access_granted = module.cluster.role_assignment_ids

  external_key_vault = {
    tenant_id                  = local.complexio_tenant_id
    external_secrets_client_id = var.external_key_vault.external_secrets_client_id
    key_vault_url              = local.external_key_vault_url
  }
  customer_key_vault = {
    tenant_id                  = data.azurerm_client_config.current.tenant_id
    external_secrets_client_id = module.workload_identity["external-secrets"].client_id
    key_vault_url              = lower(azurerm_key_vault.this.vault_uri)
  }
  oci_source_artifact = {
    url = local.oci_source_artifact_url
    ref = {
      tag = local.oci_source_artifact_tag
    }
    path = local.oci_source_artifact_path
  }
}

# --- Terraform inputs and outputs in Key Vault --------------------------------------------------

locals {
  # Every variable but the Postgres administrator password, which is a secret and, being ephemeral,
  # cannot be stored anyway.
  inputs = {
    subscription_id                            = var.subscription_id
    dns_parent_zone_subscription_id            = var.dns_parent_zone_subscription_id
    existing_network_appliance_subscription_id = var.existing_network_appliance_subscription_id
    cluster_name                               = var.cluster_name
    region                                     = var.region
    customer_name                              = var.customer_name
    resource_group_name                        = var.resource_group_name
    existing_resource_group_name               = var.existing_resource_group_name
    kubernetes_version                         = var.kubernetes_version
    managed_cluster_sku_tier                   = var.managed_cluster_sku_tier
    availability_zones                         = var.availability_zones
    core_worker_pool_vm_size                   = var.core_worker_pool_vm_size
    core_worker_pool_os_disk_size              = var.core_worker_pool_os_disk_size
    node_provisioning_mode                     = var.node_provisioning_mode
    enable_azure_container_storage             = var.enable_azure_container_storage
    existing_vnet_name                         = var.existing_vnet_name
    existing_vnet_resource_group_name          = var.existing_vnet_resource_group_name
    vnet_cidr                                  = var.vnet_cidr
    nodes_subnet_cidr                          = var.nodes_subnet_cidr
    apiserver_subnet_cidr                      = var.apiserver_subnet_cidr
    bastion_subnet_cidr                        = var.bastion_subnet_cidr
    ingress_lb_subnet_cidr                     = var.ingress_lb_subnet_cidr
    vnet_peerings                              = var.vnet_peerings
    private_cluster_enabled                    = var.private_cluster_enabled
    create_bastion                             = var.create_bastion
    create_gateway_public_ip                   = var.create_gateway_public_ip
    use_existing_network_appliance             = var.use_existing_network_appliance
    existing_network_appliance_private_ip      = var.existing_network_appliance_private_ip
    existing_network_appliance_vnet_id         = var.existing_network_appliance_vnet_id
    azure_rbac                                 = var.azure_rbac
    docker_acr_registries                      = var.docker_acr_registries
    generic_acr_registries                     = var.generic_acr_registries
    k8s_namespaces                             = var.k8s_namespaces
    azure_key_vault_name                       = var.azure_key_vault_name
    key_vault_secrets_officer_groups           = var.key_vault_secrets_officer_groups
    create_postgres                            = var.create_postgres
    postgres_name                              = var.postgres_name
    postgres_subnet_cidr                       = var.postgres_subnet_cidr
    postgres_existing_private_dns_zone_id      = var.postgres_existing_private_dns_zone_id
    postgres_version                           = var.postgres_version
    postgres_sku_name                          = var.postgres_sku_name
    postgres_zone                              = var.postgres_zone
    postgres_storage_size_mb                   = var.postgres_storage_size_mb
    postgres_storage_iops                      = var.postgres_storage_iops
    postgres_storage_throughput_mbps           = var.postgres_storage_throughput_mbps
    postgres_backup_retention_days             = var.postgres_backup_retention_days
    postgres_maintenance_window                = var.postgres_maintenance_window
    postgres_administrator_login               = var.postgres_administrator_login
    postgres_administrator_password_version    = var.postgres_administrator_password_version
    postgres_server_parameters                 = var.postgres_server_parameters
    postgres_pgbouncer_parameters              = var.postgres_pgbouncer_parameters
    postgres_extensions                        = var.postgres_extensions
    create_blob_storage                        = var.create_blob_storage
    blob_storage_account_name                  = var.blob_storage_account_name
    blob_storage_replication_type              = var.blob_storage_replication_type
    blob_storage_soft_delete_retention_days    = var.blob_storage_soft_delete_retention_days
    blob_storage_subnet_cidr                   = var.blob_storage_subnet_cidr
    blob_storage_existing_private_dns_zone_id  = var.blob_storage_existing_private_dns_zone_id
    dns_zone                                   = var.dns_zone
    dns_enable_delegation                      = var.dns_enable_delegation
    dns_parent_zone_resource_group_name        = var.dns_parent_zone_resource_group_name
    external_key_vault                         = var.external_key_vault
    tags                                       = var.tags
  }

  # Every output, which outputs.tf reads from here.
  outputs = {
    subscription_id                      = local.subscription_id
    resource_group_name                  = local.resource_group_name
    tenant_id                            = data.azurerm_client_config.current.tenant_id
    cluster_name                         = module.cluster.name
    cluster_id                           = module.cluster.id
    oidc_issuer_url                      = module.cluster.oidc_issuer_url
    private_fqdn                         = module.cluster.private_fqdn
    bastion_name                         = try(module.bastion[0].name, null)
    node_resource_group                  = module.cluster.node_resource_group
    vnet_id                              = module.network.vnet_id
    nodes_subnet_cidr                    = module.network.nodes_subnet_cidr
    egress_public_ip_address             = module.network.egress_public_ip_address
    ingress_lb_private_ip                = local.ingress_lb_private_ip
    gateway_public_ip_name               = module.cluster.gateway_public_ip_name
    gateway_public_ip_address            = module.cluster.gateway_public_ip_address
    key_vault_id                         = azurerm_key_vault.this.id
    key_vault_name                       = azurerm_key_vault.this.name
    external_secrets_identity_client_id  = module.workload_identity["external-secrets"].client_id
    inference_worker_identity_client_ids = { for ns in var.k8s_namespaces : ns => module.workload_identity["inference-worker/${ns}"].client_id }
    external_dns_identity_client_id      = try(module.workload_identity["external-dns"].client_id, null)
    cert_manager_identity_client_id      = try(module.workload_identity["cert-manager"].client_id, null)
    s3proxy_identity_client_id           = try(module.workload_identity["s3proxy"].client_id, null)
    postgres_fqdn                        = try(module.postgres[0].fqdn, null)
    blob_storage_account_name            = try(module.blob_storage[0].name, null)
    blob_storage_container_names         = try(module.blob_storage[0].container_names, null)
    child_dns_zone_name                  = try(module.dns_child_zone[0].name, null)
    child_dns_zone_name_servers          = try(module.dns_child_zone[0].name_servers, null)
  }
}

# ExternalSecrets writes a null as the string "null", so nulls are left out: a missing key fails a
# consumer that needs it instead of handing it that string.
resource "azurerm_key_vault_secret" "terraform_inputs" {
  name         = "tf-complexio-cluster--INPUTS"
  key_vault_id = terraform_data.key_vault_id_after_grants.output
  content_type = "application/json"
  value        = jsonencode({ for name, value in local.inputs : name => value if value != null })
}

resource "azurerm_key_vault_secret" "terraform_outputs" {
  name         = "tf-complexio-cluster--OUTPUTS"
  key_vault_id = terraform_data.key_vault_id_after_grants.output
  content_type = "application/json"
  value        = jsonencode({ for name, value in local.outputs : name => value if value != null })
}
