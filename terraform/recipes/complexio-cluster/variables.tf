variable "cluster_name" {
  type    = string
  default = "complexio-aks"
}

variable "region" {
  type = string
}

variable "customer_name" {
  description = "Given by Complexio. Names the customer's deployment artifact in Complexio's registry, oci://complexio.azurecr.io/deployments/<customer_name>."
  type        = string

  # It becomes a path component of an OCI repository. A stricter form of the OCI distribution spec's
  # rule, which also allows '__' and runs of '-'.
  validation {
    condition     = can(regex("^[a-z0-9]+([._-][a-z0-9]+)*$", var.customer_name))
    error_message = "customer_name must be lowercase letters and digits, optionally separated by single '.', '_' or '-', e.g. acme or acme-shipping."
  }
}

variable "resource_group_name" {
  description = "Resource group to create. Mutually exclusive with existing_resource_group_name."
  type        = string
  default     = null
}

variable "existing_resource_group_name" {
  description = "Resource group to reuse. Mutually exclusive with resource_group_name."
  type        = string
  default     = null

  validation {
    condition     = (var.resource_group_name == null) != (var.existing_resource_group_name == null)
    error_message = "Set exactly one of resource_group_name (create) or existing_resource_group_name (reuse)."
  }
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "managed_cluster_sku_tier" {
  type    = string
  default = "Standard"
}

variable "availability_zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "core_worker_pool_vm_size" {
  type    = string
  default = "Standard_B2s_v2"
}

variable "core_worker_pool_os_disk_size" {
  type    = number
  default = 64
}

variable "node_provisioning_mode" {
  description = "\"Auto\" hands node provisioning to Karpenter (NAP)."
  type        = string
  default     = "Auto"
}

variable "enable_azure_container_storage" {
  type    = bool
  default = true
}

# --- Networking ---------------------------------------------------------------------------------

variable "existing_vnet_name" {
  description = "If set, the AKS subnet is created in this VNet instead of a new one."
  type        = string
  default     = null
}

variable "existing_vnet_resource_group_name" {
  type    = string
  default = null
}

variable "vnet_cidr" {
  type    = string
  default = "10.224.0.0/16"
}

variable "nodes_subnet_cidr" {
  description = "Defaults to the first /24 of vnet_cidr. Required when existing_vnet_name is set."
  type        = string
  default     = null
}

variable "apiserver_subnet_cidr" {
  description = "Defaults to the second /24 of vnet_cidr. Required when existing_vnet_name is set."
  type        = string
  default     = null
}

variable "bastion_subnet_cidr" {
  description = "Defaults to the third /24 of vnet_cidr. Required when existing_vnet_name and create_bastion are set."
  type        = string
  default     = null
}

variable "ingress_lb_subnet_cidr" {
  description = "Subnet for the gateway's private load balancer behind an existing network appliance. Defaults to the sixth /24 of vnet_cidr. Required when existing_vnet_name and use_existing_network_appliance are set."
  type        = string
  default     = null

  validation {
    condition     = var.ingress_lb_subnet_cidr == null || var.use_existing_network_appliance
    error_message = "ingress_lb_subnet_cidr is only used with use_existing_network_appliance: without it the gateway has a public IP."
  }
}

variable "vnet_peerings" {
  description = "VNets to peer the cluster's VNet with, keyed by a name stable at plan time."
  type = map(object({
    remote_virtual_network_id    = string
    allow_virtual_network_access = optional(bool, true)
    allow_forwarded_traffic      = optional(bool, false)
    allow_gateway_transit        = optional(bool, false)
    use_remote_gateways          = optional(bool, false)
    create_reverse_peering       = optional(bool, true)
  }))
  default = {}
}

variable "private_cluster_enabled" {
  description = "Keep the API server private. Set false only for internal development clusters."
  type        = bool
  default     = true
}

variable "create_bastion" {
  description = "Create an Azure Bastion (and its subnet) to reach the private API server. Leave false when the customer has its own way in, such as a VPN."
  type        = bool
  default     = false
}

variable "create_gateway_public_ip" {
  description = "Create a static public IP for the gateway's LoadBalancer Service, kept when the Gateway or the cluster is deleted. Set false when the gateway needs no public access. Ignored with use_existing_network_appliance."
  type        = bool
  default     = true
}

variable "use_existing_network_appliance" {
  description = "Send all traffic in and out of the cluster through an existing network appliance: a firewall, or any other appliance the customer uses to manage inbound and outbound traffic, such as one in a hub reached over a VNet peering. Otherwise egress leaves through a NAT gateway. All egress goes to the appliance's private IP, and the gateway has no public IP: it gets a private IP that the appliance forwards HTTPS to. The appliance's owner keeps its egress allow-list. Decide before the cluster is created."
  type        = bool
  default     = false
}

variable "existing_network_appliance_private_ip" {
  description = "Private IP of the existing network appliance, the next hop for all egress. Required with use_existing_network_appliance."
  type        = string
  default     = null

  validation {
    condition     = !var.use_existing_network_appliance || can(cidrhost("${var.existing_network_appliance_private_ip}/32", 0))
    error_message = "Set existing_network_appliance_private_ip to an IPv4 address when use_existing_network_appliance is true."
  }
}

variable "existing_network_appliance_vnet_id" {
  description = "Resource ID of the VNet holding the existing network appliance. Terraform peers it with the cluster's VNet both ways. Set existing_network_appliance_subscription_id when it is in another subscription. Required with use_existing_network_appliance."
  type        = string
  default     = null

  validation {
    condition     = !var.use_existing_network_appliance || var.existing_network_appliance_vnet_id != null
    error_message = "Set existing_network_appliance_vnet_id when use_existing_network_appliance is true."
  }
}

# --- Access -------------------------------------------------------------------------------------

variable "azure_rbac" {
  description = "Entra group object IDs per AKS built-in role. https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac#aks-built-in-roles"
  type = object({
    admin_principal_ids         = optional(list(string), [])
    cluster_admin_principal_ids = optional(list(string), [])
    writer_principal_ids        = optional(list(string), [])
    reader_principal_ids        = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = length(var.azure_rbac.cluster_admin_principal_ids) > 0
    error_message = "The bootstrap runs kubectl as whoever runs Terraform, who must be in azure_rbac.cluster_admin_principal_ids."
  }
}

# --- Container registries -----------------------------------------------------------------------

variable "docker_acr_registries" {
  description = "Registries holding the container images the cluster's pods run."
  type = list(object({
    name                = string
    resource_group_name = string
    subscription_id     = string
  }))
  default = []
}

variable "generic_acr_registries" {
  description = "Registries holding generic OCI artifacts such as models, pulled by inference workers."
  type = list(object({
    name                = string
    resource_group_name = string
    subscription_id     = string
  }))
  default = []
}

# --- Complexio installations --------------------------------------------------------------------

variable "k8s_namespaces" {
  description = "One namespace per Complexio installation in the cluster."
  type        = list(string)
  default     = ["complexio-prod", "complexio-prodv2"]
}

# --- Key Vault ----------------------------------------------------------------------------------

variable "azure_key_vault_name" {
  description = "Key Vault names are globally unique, so a custom name is often necessary. Defaults to <cluster_name>-<random_string>."
  type        = string
  default     = null

  validation {
    condition     = var.azure_key_vault_name == null || length(var.azure_key_vault_name) <= 24
    error_message = "The Azure Key Vault name must be 24 characters or less."
  }
}

variable "key_vault_secrets_officer_groups" {
  description = "Principal IDs granted Key Vault Secrets Officer and Key Vault Certificates Officer on the Key Vault. Whoever runs this recipe or entra-app-registrations needs them."
  type        = list(string)
  default     = []
}

# --- PostgreSQL ----------------------------------------------------------------------------------

variable "create_postgres" {
  description = "Create a private PostgreSQL flexible server in the same VNet."
  type        = bool
  default     = true
}

variable "postgres_name" {
  description = "Server names are globally unique (<name>.postgres.database.azure.com), so a custom name is often necessary. Defaults to <cluster_name>-pg-<random_string>."
  type        = string
  default     = null

  validation {
    condition     = var.postgres_name == null || can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.postgres_name))
    error_message = "The Postgres server name must be 3 to 63 characters of lowercase letters, digits and hyphens, and cannot start or end with a hyphen."
  }
}

variable "postgres_subnet_cidr" {
  description = "Range of the server's delegated subnet, a /28 at least. Defaults to the fourth /24 of vnet_cidr. Required when existing_vnet_name is set."
  type        = string
  default     = null

  validation {
    condition     = !var.create_postgres || var.existing_vnet_name == null || var.postgres_subnet_cidr != null
    error_message = "Set postgres_subnet_cidr explicitly when existing_vnet_name is used."
  }
}

variable "postgres_existing_private_dns_zone_id" {
  description = "An existing privatelink.postgres.database.azure.com zone already linked to the cluster's VNet. Created when unset."
  type        = string
  default     = null
}

variable "postgres_version" {
  description = "Postgres major version."
  type        = string
  default     = "18"
}

variable "postgres_sku_name" {
  description = "Compute SKU, prefixed with its tier: MO_ (memory optimized), GP_ (general purpose) or B_ (burstable). Use MO_Standard_E16ds_v5 where v6 is not available in the region."
  type        = string
  default     = "MO_Standard_E16ds_v5"
}

variable "postgres_zone" {
  description = "Availability zone of the server, read at creation only. Azure picks one when unset."
  type        = string
  default     = null
}

variable "postgres_storage_size_mb" {
  description = "Premium SSD v2 disk size in MB. 2097152 = 2 TB."
  type        = number
  default     = 2097152
}

variable "postgres_storage_iops" {
  description = "Provisioned disk IOPS."
  type        = number
  default     = 12000
}

variable "postgres_storage_throughput_mbps" {
  description = "Provisioned disk throughput in MB/s."
  type        = number
  default     = 1000
}

variable "postgres_backup_retention_days" {
  description = "Days of backups kept, between 7 and 35."
  type        = number
  default     = 14
}

variable "postgres_maintenance_window" {
  description = "Weekly maintenance window in UTC; day_of_week 0 is Sunday."
  type = object({
    day_of_week  = optional(number, 0)
    start_hour   = optional(number, 2)
    start_minute = optional(number, 0)
  })
  default = { day_of_week = 0, start_hour = 2, start_minute = 0 }
}

variable "postgres_administrator_login" {
  type    = string
  default = "complexio"
}

variable "postgres_administrator_password_version" {
  description = "Increasing it rotates the administrator password: Terraform sends the current postgres_administrator_password, or a newly generated one, to the server and the Key Vault again. Always consult Complexio before changing it."
  type        = number
  default     = 1
}

variable "postgres_server_parameters" {
  description = "Postgres server parameters, merged over the module's defaults (tuned from the SKU's vCPUs and memory). Values are in each parameter's base unit (pg_settings.unit), e.g. ms for idle_in_transaction_session_timeout. A parameter removed from both keeps its last value on the server: set it to its default to revert it."
  type        = map(string)
  default     = {}
}

variable "postgres_pgbouncer_parameters" {
  description = "pgbouncer.* server parameters, merged over the module's defaults: pgbouncer.enabled = true, pgbouncer.max_prepared_statements = 256. The others are dropped while pgbouncer.enabled is false. A parameter removed from both keeps its last value on the server: set it to its default to revert it."
  type        = map(string)
  default     = {}
}

variable "postgres_extensions" {
  description = "Extensions allowed on the server (azure.extensions). Null keeps the module's list: vector, pg_stat_statements, pg_trgm, pgstattuple, uuid-ossp and btree_gin."
  type        = list(string)
  default     = null
}

variable "postgres_administrator_password" {
  description = "Set through TF_VAR_postgres_administrator_password. Generated when unset."
  type        = string
  sensitive   = true
  ephemeral   = true
  default     = null
}

# --- Blob storage -------------------------------------------------------------------------------

variable "create_blob_storage" {
  description = "Create the storage account behind S3Proxy, reachable through a private endpoint in the cluster's VNet, and the s3proxy and neo4j-backup workload identities that read and write it."
  type        = bool
  default     = true
}

variable "blob_storage_account_name" {
  description = "Account names are globally unique (<name>.blob.core.windows.net), so a custom name is often necessary. Defaults to the cluster name's letters and digits followed by a random string."
  type        = string
  default     = null

  validation {
    condition     = var.blob_storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.blob_storage_account_name))
    error_message = "The storage account name must be 3 to 24 lowercase letters and digits."
  }
}

variable "blob_storage_replication_type" {
  description = "LRS, ZRS, GRS, RAGRS, GZRS or RAGZRS."
  type        = string
  default     = "ZRS"
}

variable "blob_storage_soft_delete_retention_days" {
  description = "Days a deleted blob or container can be restored for, between 1 and 365."
  type        = number
  default     = 30
}

variable "blob_storage_subnet_cidr" {
  description = "Range of the private endpoint's subnet. Defaults to the fifth /24 of vnet_cidr. Required when existing_vnet_name is set."
  type        = string
  default     = null

  validation {
    condition     = !var.create_blob_storage || var.existing_vnet_name == null || var.blob_storage_subnet_cidr != null
    error_message = "Set blob_storage_subnet_cidr explicitly when existing_vnet_name is used."
  }
}

variable "blob_storage_existing_private_dns_zone_id" {
  description = "An existing privatelink.blob.core.windows.net zone already linked to the cluster's VNet. Created when unset."
  type        = string
  default     = null
}

# --- DNS ----------------------------------------------------------------------------------------

variable "dns_zone" {
  description = "Child zone to create, named \"<prefix>.<parent_zone_name>\". Leave unset to not manage DNS."
  type = object({
    prefix           = string
    parent_zone_name = string
  })
  default = null

  validation {
    condition     = var.dns_zone == null || can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$", var.dns_zone.prefix))
    error_message = "dns_zone.prefix must be one or more DNS labels: letters, digits and inner hyphens, e.g. \"acme\" or \"acme.eu\"."
  }

  validation {
    condition     = var.dns_zone == null || !endswith(var.dns_zone.prefix, var.dns_zone.parent_zone_name)
    error_message = "dns_zone.prefix is the part in front of the parent zone, not the full name: use \"acme\", not \"acme.example.com\"."
  }
}

variable "dns_enable_delegation" {
  description = "Write an NS record into the parent zone so it answers queries for the child zone. Requires write access to the parent zone."
  type        = bool
  default     = false

  validation {
    condition     = !var.dns_enable_delegation || var.dns_zone != null
    error_message = "dns_enable_delegation does nothing without dns_zone: there is no child zone to delegate to."
  }
}

variable "dns_parent_zone_resource_group_name" {
  description = "Resource group of the parent DNS zone. Defaults to the cluster's resource group."
  type        = string
  default     = null
}

# --- Bootstrap ----------------------------------------------------------------------------------

variable "external_key_vault" {
  description = "Given by Complexio: the Key Vault it creates for this customer in its own tenant, by name (the <name> in https://<name>.vault.azure.net), and the client ID of the identity ExternalSecrets reads it with. The bootstrap points ExternalSecrets at it to get the ACR token Flux pulls the top-level artifact with."
  type = object({
    external_secrets_client_id = string
    name                       = string
  })

  # Azure's rule for vault names, checked here so that a bad name is reported against this input
  # rather than against the URL the bootstrap module builds from it.
  validation {
    condition = (
      length(var.external_key_vault.name) >= 3 && length(var.external_key_vault.name) <= 24
      && can(regex("^[a-zA-Z]([a-zA-Z0-9]|-[a-zA-Z0-9])*$", var.external_key_vault.name))
    )
    error_message = "external_key_vault.name must be a Key Vault name: 3 to 24 letters, digits and single hyphens, starting with a letter and ending with a letter or digit."
  }
}

# --- Misc ---------------------------------------------------------------------------------------

variable "tags" {
  description = "Applied to every taggable resource this recipe creates."
  type        = map(string)
  default     = {}
}
