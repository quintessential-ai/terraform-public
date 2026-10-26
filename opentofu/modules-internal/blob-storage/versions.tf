terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # public_network_access on azurerm_storage_account.
      version = ">= 5.5"
    }
  }
}
