variable "cluster_name" {
  type    = string
  default = "complexio-aks"
}

variable "default_location" {
  type = string
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
  default = null
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
  default = "standard_d4s_v6"
}

variable "core_worker_pool_os_disk_size" {
  type    = number
  default = 128
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
  description = "Create a static public IP for the gateway's LoadBalancer Service, kept when the Gateway or the cluster is deleted. Set false when the gateway needs no public access."
  type        = bool
  default     = true
}

# --- Access -------------------------------------------------------------------------------------

variable "azure_rbac" {
  description = "Entra group object IDs per AKS built-in role. https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac#aks-built-in-roles"
  type = object({
    enabled                     = optional(bool, true)
    admin_principal_ids         = optional(list(string), [])
    cluster_admin_principal_ids = optional(list(string), [])
    writer_principal_ids        = optional(list(string), [])
    reader_principal_ids        = optional(list(string), [])
  })
  default = {}
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

variable "create_azure_key_vault" {
  description = "Create a Key Vault dedicated to this cluster."
  type        = bool
  default     = false
}

variable "azure_key_vault_name" {
  description = "Key Vault names are globally unique, so a custom name is often necessary. Defaults to <cluster_name>-<random_string>."
  type        = string
  default     = null

  validation {
    condition     = var.azure_key_vault_name == null || length(var.azure_key_vault_name) <= 24
    error_message = "The Azure Key Vault name must be 24 characters or less."
  }
}

variable "existing_azure_key_vault" {
  description = "Key Vault to grant the cluster's secret operators access to. Optional; resource group and subscription default to the cluster's."
  type = object({
    name                = string
    resource_group_name = optional(string)
    subscription_id     = optional(string)
  })
  default = null
}

variable "postgres" {
  type = object({
    name                           = optional(string)
    subnet_cidr                    = optional(string)
    existing_private_dns_zone_id   = optional(string)
    postgres_version               = optional(string)
    sku_name                       = optional(string)
    zone                           = optional(string)
    storage                        = object({ size_mb = number, iops = number, throughput_mbps = number })
    backup_retention_days          = optional(number)
    maintenance_window             = optional(object({ day_of_week = optional(number, 0), start_hour = optional(number, 0), start_minute = optional(number, 0) }))
    administrator_login            = optional(string)
    administrator_password_version = optional(number)
    server_parameters              = optional(map(string))
    extensions                     = optional(list(string))
  })
  default = null

  validation {
    condition     = var.postgres == null || var.existing_vnet_name == null || try(var.postgres.subnet_cidr, null) != null
    error_message = "Set postgres.subnet_cidr explicitly when existing_vnet_name is used."
  }
}

variable "postgres_administrator_password" {
  description = "Set through TF_VAR_postgres_administrator_password. Generated when unset."
  type        = string
  sensitive   = true
  ephemeral   = true
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

# --- Misc ---------------------------------------------------------------------------------------

variable "tags" {
  description = "Applied to every taggable resource this recipe creates."
  type        = map(string)
  default     = {}
}
