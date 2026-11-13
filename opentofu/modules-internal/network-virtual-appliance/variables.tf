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
  description = "VNet the appliance's subnet is created in."
  type        = string
}

variable "subnet_cidr" {
  description = "Range of the appliance's subnet. The internal load balancer takes its fifth address, the next hop of the nodes' egress. A /28 at least."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr)) && tonumber(split("/", var.subnet_cidr)[1]) <= 28
    error_message = "subnet_cidr must be an IPv4 CIDR of at least a /28."
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
    condition     = length(var.ingress_ports) > 0 && alltrue([for port in var.ingress_ports : port >= 1 && port <= 65535 && port != 8080])
    error_message = "ingress_ports must list ports from 1 to 65535. 8080 is taken by the health endpoint."
  }
}

variable "vm_size" {
  description = "Size of each instance. A burstable B-series size forwards at full speed only while it has CPU credits."
  type        = string
  default     = "Standard_B2pts_v2"
}

variable "instance_count" {
  description = "Instances sharing the traffic. Each keeps its own connections, which a crash drops."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 15
    error_message = "instance_count must be between 1 and 15: each instance needs at least 4,000 SNAT ports of the public IP's 64,000."
  }
}

variable "availability_zones" {
  description = "Zones the instances and the load balancers' frontends are spread across."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
