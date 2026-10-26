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
}

variable "existing_vnet_name" {
  description = "If set, the subnet is created in this VNet instead of a new one."
  type        = string
  default     = null
}

variable "existing_vnet_resource_group_name" {
  description = "Defaults to this module's resource group."
  type        = string
  default     = null
}

variable "nodes_subnet_name" {
  type    = string
  default = "aks-nodes"
}

variable "nodes_subnet_cidr" {
  description = "Defaults to the first block of vnet_cidr, sized by subnet_newbits. Required when attaching to an existing VNet."
  type        = string
  default     = null

  validation {
    condition     = var.existing_vnet_name == null || var.nodes_subnet_cidr != null
    error_message = "Set nodes_subnet_cidr explicitly when existing_vnet_name is used: the module cannot know which ranges are free in a VNet it did not create."
  }
}

variable "apiserver_subnet_name" {
  type    = string
  default = "aks-apiserver"
}

variable "apiserver_subnet_cidr" {
  description = "Defaults to the second block of vnet_cidr, sized by subnet_newbits. Required when attaching to an existing VNet."
  type        = string
  default     = null

  validation {
    condition     = var.existing_vnet_name == null || var.apiserver_subnet_cidr != null
    error_message = "Set apiserver_subnet_cidr explicitly when existing_vnet_name is used."
  }
}

variable "create_bastion_subnet" {
  description = "Create the AzureBastionSubnet for Azure Bastion access to the API server."
  type        = bool
  default     = false
}

variable "bastion_subnet_cidr" {
  description = "Defaults to the third block of vnet_cidr, sized by subnet_newbits. Required when attaching to an existing VNet."
  type        = string
  default     = null

  validation {
    condition     = var.existing_vnet_name == null || !var.create_bastion_subnet || var.bastion_subnet_cidr != null
    error_message = "Set bastion_subnet_cidr explicitly when existing_vnet_name is used."
  }
}

variable "ingress_lb_subnet_cidr" {
  description = "Range of the aks-ingress-lb subnet, created with route_egress_to_network_appliance. Defaults to the sixth block of vnet_cidr, sized by subnet_newbits. Required when attaching to an existing VNet."
  type        = string
  default     = null

  validation {
    condition     = var.existing_vnet_name == null || !var.route_egress_to_network_appliance || var.ingress_lb_subnet_cidr != null
    error_message = "Set ingress_lb_subnet_cidr explicitly when existing_vnet_name is used."
  }
}

variable "subnet_newbits" {
  description = "Bits added to the VNet prefix to size the derived subnet: 8 turns a /16 into a /24."
  type        = number
  default     = 8
}

variable "route_egress_to_network_appliance" {
  description = "Route all egress from the nodes subnet to network_appliance_ip. Otherwise it leaves through a NAT gateway this module creates."
  type        = bool
  default     = false
}

variable "network_appliance_ip" {
  description = "Private IP of the network appliance that takes the nodes' egress. Required with route_egress_to_network_appliance."
  type        = string
  default     = null

  validation {
    condition     = !var.route_egress_to_network_appliance || var.network_appliance_ip != null
    error_message = "Set network_appliance_ip when route_egress_to_network_appliance is true."
  }
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
