variable "tenant_id" {
  description = "Your Microsoft Entra tenant, where the app registrations are created."
  type        = string
}

variable "subscription_id" {
  description = "Subscription of the Key Vault the credentials are written to."
  type        = string
}

provider "azuread" {
  tenant_id = var.tenant_id
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}
