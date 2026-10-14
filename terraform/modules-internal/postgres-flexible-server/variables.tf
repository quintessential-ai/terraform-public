variable "name" {
  description = "Globally unique: it becomes <name>.postgres.database.azure.com."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  description = "Defaults to the resource group's location. Must match the VNet's."
  type        = string
  default     = null
}

# --- Networking -----------------------------------------------------------------------------------

variable "vnet_id" {
  description = "VNet the server is injected into. Its subnet is created here unless existing_subnet_id is set."
  type        = string
  default     = null
}

variable "subnet_name" {
  description = "Defaults to <name>-subnet."
  type        = string
  default     = null
}

variable "subnet_cidr" {
  description = "Range of the delegated subnet created for the server. A /28 is the minimum."
  type        = string
  default     = null

  validation {
    condition     = var.subnet_cidr == null || (can(cidrnetmask(var.subnet_cidr)) && tonumber(split("/", var.subnet_cidr)[1]) <= 28)
    error_message = "subnet_cidr must be a valid CIDR of at least a /28."
  }
}

variable "existing_subnet_id" {
  description = "A subnet already delegated to Microsoft.DBforPostgreSQL/flexibleServers."
  type        = string
  default     = null

  validation {
    condition     = (var.existing_subnet_id == null) != (var.vnet_id == null || var.subnet_cidr == null)
    error_message = "Set either existing_subnet_id, or both vnet_id and subnet_cidr."
  }
}

variable "existing_private_dns_zone_id" {
  description = "A privatelink.postgres.database.azure.com zone already linked to the VNet. Created and linked to vnet_id when unset."
  type        = string
  default     = null

  validation {
    condition     = var.existing_private_dns_zone_id != null || var.vnet_id != null
    error_message = "vnet_id is required to link the private DNS zone this module creates."
  }
}

# --- Server ---------------------------------------------------------------------------------------

variable "postgres_version" {
  type     = string
  default  = "18"
  nullable = false
}

variable "sku_name" {
  description = "Prefixed with the tier: MO_ (memory optimized), GP_ (general purpose) or B_ (burstable)."
  type        = string
  default     = "MO_Standard_E16ds_v6"
  nullable    = false
}

variable "zone" {
  description = "Availability zone of the primary. Azure picks one when unset."
  type        = string
  default     = null
}

variable "storage" {
  description = "Premium SSD v2 disk. size_mb: disk size in MB, 2097152 = 2 TB. iops: provisioned disk IOPS. throughput_mbps: provisioned disk throughput in MB/s."
  type = object({
    size_mb         = number
    iops            = number
    throughput_mbps = number
  })
}

variable "backup_retention_days" {
  type     = number
  default  = 14
  nullable = false

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 7 and 35."
  }
}

variable "maintenance_window" {
  description = "In UTC; day_of_week 0 is Sunday. Defaults to Sunday 02:00."
  type = object({
    day_of_week  = optional(number, 0)
    start_hour   = optional(number, 0)
    start_minute = optional(number, 0)
  })
  default  = { day_of_week = 0, start_hour = 2, start_minute = 0 }
  nullable = false
}

variable "server_parameters" {
  description = "Postgres server parameters, merged over the module's defaults (tuned from the SKU's vCPUs and memory). Values are in each parameter's base unit (pg_settings.unit)."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "extensions" {
  description = "Extensions allowed on the server (azure.extensions)."
  type        = list(string)
  default     = ["vector", "pg_stat_statements", "pg_trgm", "pgstattuple", "uuid-ossp", "btree_gin"]
  nullable    = false
}

# --- Access ---------------------------------------------------------------------------------------

variable "administrator_login" {
  description = "Postgres administrator username."
  type        = string
  default     = "complexio"
  nullable    = false
}

variable "administrator_password" {
  description = "Generated when unset. Sent through write-only arguments, so it is never stored in state."
  type        = string
  sensitive   = true
  ephemeral   = true
  default     = null
}

variable "administrator_password_version" {
  description = "Increasing this value rotates the administrator password: Terraform sends the current administrator_password to the server again. Always consult Complexio before changing it."
  type        = number
  default     = 1
  nullable    = false
}

variable "key_vault_id" {
  description = "Key Vault the administrator login and password are stored in, as deployments-prod--PGUSER and deployments-prod--PGPASSWORD."
  type        = string
}

variable "tags" {
  type     = map(string)
  default  = {}
  nullable = false
}
