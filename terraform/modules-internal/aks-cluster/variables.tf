variable "cluster_name" {
  type = string
}

variable "location" {
  description = "Defaults to the resource group's location."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Resource group the cluster and, unless an existing VNet is used, the VNet live in."
  type        = string
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "sku_tier" {
  description = "Control-plane SKU tier: Free, Standard or Premium."
  type        = string
  default     = "Standard"
}

variable "dns_prefix" {
  description = "It sets the prefix for the cluster's Fully Qualified Domain Name. If empty, it defaults to the resource_group_name."
  type        = string
  default     = null
}

variable "nodes_subnet_id" {
  description = "Subnet the core node pool and, by default, Karpenter provision into."
  type        = string
}

variable "private_cluster_enabled" {
  description = "Keep the API server private. Set false only for internal development clusters."
  type        = bool
  default     = true
}

variable "apiserver_subnet_id" {
  description = "Subnet delegated to AKS for the private API server (API Server VNet Integration)."
  type        = string
}

variable "vnet_id" {
  description = "VNet holding nodes_subnet_id. The cluster identity is granted Network Contributor on it."
  type        = string
}

# --- Cluster networking ---------------------------------------------------------------------------
# Overlay ranges, internal to the cluster. They do not consume VNet address space.

variable "pod_cidr" {
  type    = string
  default = "172.16.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "172.17.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "172.17.255.254"
}

# --- Core node pool -----------------------------------------------------------------------------

variable "availability_zones" {
  description = "Every Azure region with availability zones names them \"1\", \"2\" and \"3\"."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "core_pool_vm_size" {
  description = "Older or very new VM types are not available in every zone, which fails cluster creation."
  type        = string
  default     = "standard_d4s_v6"
}

variable "core_pool_node_count" {
  type    = number
  default = 2
}

variable "core_pool_os_disk_size_gb" {
  type    = number
  default = 128
}

# --- RBAC Access to the cluster ------------------------------------------------------------------

variable "principal_ids" {
  description = "Entra group object IDs to grant each AKS built-in role to."
  type = object({
    cluster_admin = optional(list(string), [])
    admin         = optional(list(string), [])
    writer        = optional(list(string), [])
    reader        = optional(list(string), [])
  })
  default = {}
}

# --- Features -----------------------------------------------------------------------------------

variable "tenant_id" {
  description = "Entra tenant backing the cluster's AAD integration. Defaults to the provider's own tenant."
  type        = string
  default     = null
}

variable "azure_rbac_enabled" {
  description = "Delegate Kubernetes authorization to Azure RBAC."
  type        = bool
  default     = true
}

variable "node_provisioning_mode" {
  description = "\"Auto\" hands node provisioning to Karpenter (NAP); \"Manual\" uses node pools only."
  type        = string
  default     = "Auto"
}

variable "enable_azure_container_storage" {
  description = "Local NVMe-backed storage for pods, e.g. fast model loading on GPU nodes."
  type        = bool
  default     = true
}

variable "acr_ids" {
  description = "Container registries the kubelet may pull images from, keyed by a plan-time-stable name."
  type        = map(string)
  default     = {}
}

variable "create_gateway_public_ip" {
  description = "Create a static public IP for the gateway's LoadBalancer Service, kept when the Gateway is deleted. Set false when the gateway needs no public access."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
