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

# Reads Complexio - Backend's Microsoft Graph grant, which the azuread provider cannot, to keep the
# mail write an Entra administrator approved. Signs in like azuread.
provider "msgraph" {
  tenant_id = var.tenant_id
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}

  # The recipe uses Key Vault and role assignments only, so applying needs no right to register
  # resource providers in the subscription. It is azurerm 5's default; set here so it stays so.
  resource_provider_registrations = "none"
}
