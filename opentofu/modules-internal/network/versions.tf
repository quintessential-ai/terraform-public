terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.0"
      # The network appliance's VNet may live in another subscription.
      configuration_aliases = [azurerm.network_appliance]
    }
  }
}
