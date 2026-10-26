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

variable "subnet_id" {
  description = "AzureBastionSubnet in the VNet holding the private API server."
  type        = string
}

variable "subnet_cidr" {
  description = "Range of subnet_id, the source the NSG rules match."
  type        = string
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

variable "gateway_public_ip" {
  description = "The gateway's public IP when its LoadBalancer Service is public; the nodes NSG lets the internet reach it on 443. An object so that whether it is set is known at plan time, before the address is."
  type = object({
    address = string
  })
  default = null
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
