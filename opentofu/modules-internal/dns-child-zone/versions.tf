terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.0"
      # The parent zone frequently lives in another subscription.
      configuration_aliases = [azurerm.parent]
    }
  }
}
