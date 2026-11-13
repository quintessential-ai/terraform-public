variable "cluster_name" {
  type = string
}

variable "region" {
  description = "Region of the cluster. Must match the VNet's."
  type        = string
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

variable "nodes_subnet_cidr" {
  description = "Range of the aks-nodes subnet, which the core node pool and, by default, Karpenter provision into. A /24 at least."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.nodes_subnet_cidr)) && tonumber(split("/", var.nodes_subnet_cidr)[1]) <= 24
    error_message = "nodes_subnet_cidr must be an IPv4 CIDR of at least a /24."
  }
}

variable "private_cluster_enabled" {
  description = "Keep the API server private. Set false only for internal development clusters."
  type        = bool
  default     = true
}

variable "apiserver_subnet_cidr" {
  description = "Range of the aks-apiserver subnet, delegated to AKS for the private API server (API Server VNet Integration). A /27 at least."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.apiserver_subnet_cidr)) && tonumber(split("/", var.apiserver_subnet_cidr)[1]) <= 27
    error_message = "apiserver_subnet_cidr must be an IPv4 CIDR of at least a /27."
  }
}

variable "ingress_lb_subnet_cidr" {
  description = "Range of the aks-ingress-lb subnet, for the gateway's internal load balancer. A /29 at least: Azure reserves five addresses in every subnet, and the gateway takes the fifth."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.ingress_lb_subnet_cidr)) && tonumber(split("/", var.ingress_lb_subnet_cidr)[1]) <= 29
    error_message = "ingress_lb_subnet_cidr must be an IPv4 CIDR of at least a /29."
  }
}

variable "vnet_id" {
  description = "VNet the subnets are created in. The cluster identity is granted Network Contributor on it."
  type        = string
}

variable "network_appliance_ip" {
  description = "Private IP of the network appliance that takes all the nodes' egress. It must be reachable before the cluster is created: its nodes need egress to start."
  type        = string

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.network_appliance_ip)) && can(cidrhost("${var.network_appliance_ip}/32", 0))
    error_message = "network_appliance_ip must be an IPv4 address: it is the next hop of the route to the internet."
  }
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

  validation {
    condition     = try(cidrhost("${var.dns_service_ip}/${split("/", var.service_cidr)[1]}", 0) == cidrhost(var.service_cidr, 0), false)
    error_message = "dns_service_ip must be an address in service_cidr: AKS fails to create the cluster otherwise."
  }
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

variable "tags" {
  type    = map(string)
  default = {}
}
