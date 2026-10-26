variable "name" {
  description = "Globally unique: it becomes <name>.blob.core.windows.net."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "The storage account name must be 3 to 24 lowercase letters and digits."
  }
}

variable "resource_group_name" {
  type = string
}

variable "region" {
  description = "Region of the account and its private endpoint. Must match the VNet's."
  type        = string
}

# --- Networking -----------------------------------------------------------------------------------

variable "vnet_id" {
  description = "VNet the private endpoint lives in. Its subnet is created here unless existing_subnet_id is set."
  type        = string
}

variable "subnet_name" {
  description = "Defaults to <name>-subnet."
  type        = string
  default     = null
}

variable "subnet_cidr" {
  description = "Range of the subnet created for the private endpoint."
  type        = string
  default     = null

  validation {
    condition     = var.subnet_cidr == null || can(cidrnetmask(var.subnet_cidr))
    error_message = "subnet_cidr must be a valid CIDR."
  }
}

variable "existing_subnet_id" {
  description = "A subnet to place the private endpoint in."
  type        = string
  default     = null

  validation {
    condition     = (var.existing_subnet_id == null) != (var.subnet_cidr == null)
    error_message = "Set either existing_subnet_id or subnet_cidr."
  }
}

variable "existing_private_dns_zone_id" {
  description = "A privatelink.blob.core.windows.net zone already linked to the VNet. Created and linked to vnet_id when unset."
  type        = string
  default     = null
}

# --- Storage --------------------------------------------------------------------------------------

variable "replication_type" {
  description = "LRS, ZRS, GRS, RAGRS, GZRS or RAGZRS."
  type        = string
  default     = "ZRS"
  nullable    = false
}

variable "soft_delete_retention_days" {
  description = "Days a deleted blob or container can be restored for."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days must be between 1 and 365."
  }
}

variable "container_names" {
  description = "Containers created with the account. Clients with Storage Blob Data Contributor on the account can create more."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for name in var.container_names : can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", name)) && !strcontains(name, "--")
    ])
    error_message = "Container names must be 3 to 63 lowercase letters, digits and single hyphens, and start and end with a letter or digit."
  }
}

variable "tags" {
  type     = map(string)
  default  = {}
  nullable = false
}
