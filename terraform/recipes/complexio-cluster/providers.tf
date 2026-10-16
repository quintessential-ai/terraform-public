variable "subscription_id" {
  description = "Subscription the cluster and its resource group live in."
  type        = string
}

variable "dns_parent_zone_subscription_id" {
  description = "Subscription of the parent DNS zone. Defaults to the cluster's subscription."
  type        = string
  default     = null
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    # The postgres module restarts the server once, after all its parameters are written.
    postgresql_flexible_server {
      restart_server_on_configuration_value_change = false
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
}

# The parent DNS zone frequently lives in a different subscription from the cluster.
provider "azurerm" {
  alias           = "parent_dns"
  subscription_id = coalesce(var.dns_parent_zone_subscription_id, var.subscription_id)
  features {}
}
