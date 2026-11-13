variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "region" {
  description = "Region of the Bastion. Must match the VNet's."
  type        = string
}

variable "vnet_id" {
  description = "VNet holding the private API server, where the AzureBastionSubnet is created."
  type        = string
}

variable "subnet_cidr" {
  description = "Range of the AzureBastionSubnet, and the source the NSG rules match. A /26 at least."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr)) && tonumber(split("/", var.subnet_cidr)[1]) <= 26
    error_message = "subnet_cidr must be an IPv4 CIDR of at least a /26: Azure Bastion refuses a smaller subnet."
  }
}

variable "apiserver_subnet_id" {
  type = string
}

variable "apiserver_subnet_cidr" {
  type = string
}

variable "nodes_subnet_id" {
  type = string
}

variable "tunnel_principal_ids" {
  description = "Entra group object IDs allowed to open a tunnel through this Bastion."
  type        = list(string)
  default     = []
}

variable "scale_units" {
  description = "Instances, each handling a share of concurrent sessions. 2 to 50."
  type        = number
  default     = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
