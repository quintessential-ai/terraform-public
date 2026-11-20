variable "name" {
  description = "Name of the Bastion and its public IP; its two NSGs are named after it."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the Bastion, its public IP and its NSGs are created in."
  type        = string
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
  description = "Subnet of the AKS API server. Gets an NSG that lets the Bastion reach the API server and nothing else."
  type        = string
}

variable "apiserver_subnet_cidr" {
  description = "Range of the API server subnet, which the NSG lets the Bastion reach on 443 and 4443."
  type        = string
}

variable "nodes_subnet_id" {
  description = "Subnet of the AKS nodes. Gets an NSG that keeps the Bastion from reaching the nodes."
  type        = string
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
  description = "Applied to every taggable resource this module creates."
  type        = map(string)
  default     = {}
}
