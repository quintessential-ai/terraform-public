variable "resource_group_name" {
  description = "Resource group the zone is created in."
  type        = string
}

variable "dns_zone" {
  description = "Child zone to create, named \"<prefix>.<parent_zone_name>\"."
  type = object({
    prefix           = string
    parent_zone_name = string
  })

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$", var.dns_zone.prefix))
    error_message = "dns_zone.prefix must be one or more DNS labels: letters, digits and inner hyphens, e.g. \"acme\" or \"acme.eu\"."
  }

  validation {
    condition     = !endswith(var.dns_zone.prefix, var.dns_zone.parent_zone_name)
    error_message = "dns_zone.prefix is the part in front of the parent zone, not the full name: use \"acme\", not \"acme.example.com\"."
  }
}

variable "dns_enable_delegation" {
  description = "Write an NS record into the parent zone so it answers queries for the child zone. Requires write access to the parent zone."
  type        = bool
  default     = false
}

variable "dns_parent_zone_resource_group_name" {
  description = "Resource group of the parent DNS zone. Defaults to the cluster's resource group."
  type        = string
  default     = null
}

variable "ns_record_ttl" {
  type    = number
  default = 3600
}

variable "tags" {
  type    = map(string)
  default = {}
}
