terraform {
  required_version = ">= 1.12.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.13"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7"
    }
  }
}
