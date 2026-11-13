variable "vnet_name" {
  description = "Name of the VNet to create. Ignored when existing_vnet_name is set."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "region" {
  description = "Region of the VNet and the egress route table."
  type        = string
}

variable "vnet_cidr" {
  description = "Address space of the VNet this module creates. Ignored when existing_vnet_name is set."
  type        = string
  default     = "10.224.0.0/16"

  validation {
    condition     = var.existing_vnet_name != null || can(cidrnetmask(var.vnet_cidr))
    error_message = "vnet_cidr must be an IPv4 CIDR."
  }
}

variable "existing_vnet_name" {
  description = "If set, this VNet is used instead of creating one."
  type        = string
  default     = null
}

variable "existing_vnet_resource_group_name" {
  description = "Defaults to this module's resource group."
  type        = string
  default     = null
}

variable "network_appliance_ip" {
  description = "Private IP of the network appliance that takes the nodes' egress. Given back as the network_appliance_ip output once the appliance is reachable from this VNet."
  type        = string
}

variable "network_appliance_vnet_id" {
  description = "VNet holding network_appliance_ip, when it is not this one. Peered both ways with this VNet; its side is created with the azurerm.network_appliance provider."
  type        = string
  default     = null

  validation {
    condition     = var.network_appliance_vnet_id == null || can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$", var.network_appliance_vnet_id))
    error_message = "network_appliance_vnet_id must be a full VNet resource ID."
  }
}

variable "peerings" {
  description = "VNets to peer this one with, keyed by a name that is stable at plan time."
  type = map(object({
    remote_virtual_network_id    = string
    allow_virtual_network_access = optional(bool, true)
    allow_forwarded_traffic      = optional(bool, false)
    allow_gateway_transit        = optional(bool, false)
    use_remote_gateways          = optional(bool, false)
    # A peering only carries traffic once both directions exist. The reverse side is created with
    # this module's provider, so it only works when the remote VNet is in the same subscription;
    # turn this off for a cross-subscription peer and create that side where the remote VNet lives.
    create_reverse_peering = optional(bool, true)
  }))
  default = {}

  validation {
    condition = alltrue([for p in values(var.peerings) :
      can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$", p.remote_virtual_network_id))
    ])
    error_message = "Each remote_virtual_network_id must be a full VNet resource ID."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
