variable "name" {
  description = "Prefix of every resource's name."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vnet_id" {
  description = "VNet the firewall's subnets are created in."
  type        = string
}

variable "subnet_cidr" {
  description = "Range split into the firewall's two /26 subnets: AzureFirewallSubnet and, for the Basic tier, AzureFirewallManagementSubnet. A /25 at least."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr)) && tonumber(split("/", var.subnet_cidr)[1]) <= 25
    error_message = "subnet_cidr must be an IPv4 CIDR of at least a /25: Azure Firewall takes two /26 subnets."
  }
}

variable "egress_source_cidrs" {
  description = "Ranges allowed to reach the internet through the firewall, on any protocol and port."
  type        = list(string)

  validation {
    condition     = length(var.egress_source_cidrs) > 0 && alltrue([for cidr in var.egress_source_cidrs : can(cidrnetmask(cidr))])
    error_message = "egress_source_cidrs must list IPv4 CIDRs."
  }
}

variable "ingress_target_ip" {
  description = "Private IP the ingress ports are forwarded to: the gateway's internal load balancer."
  type        = string

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.ingress_target_ip)) && can(cidrhost("${var.ingress_target_ip}/32", 0))
    error_message = "ingress_target_ip must be an IPv4 address."
  }
}

variable "ingress_ports" {
  description = "TCP ports of the public IP forwarded to ingress_target_ip."
  type        = list(number)
  default     = [443]

  validation {
    condition     = length(var.ingress_ports) > 0 && alltrue([for port in var.ingress_ports : port >= 1 && port <= 65535])
    error_message = "ingress_ports must list ports from 1 to 65535."
  }
}

variable "sku_tier" {
  description = "Basic forwards up to 250 Mbps. Standard scales up to 30 Gbps. Moving to or from Basic replaces the firewall."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Basic or Standard."
  }
}

variable "availability_zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
