# A user-assigned identity federated to a Kubernetes ServiceAccount, so pods annotated with its
# client ID can assume Azure roles without a secret.
# https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster

# Only read when the caller leaves location unset.
data "azurerm_resource_group" "this" {
  count = var.location == null ? 1 : 0
  name  = var.resource_group_name
}

locals {
  location = coalesce(var.location, one(data.azurerm_resource_group.this[*].location))
  name     = "${var.name_prefix}-${var.namespace}-${var.service_account_name}"
}

resource "azurerm_user_assigned_identity" "this" {
  name                = local.name
  resource_group_name = var.resource_group_name
  location            = local.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "this" {
  name                      = local.name
  user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id         = azurerm_user_assigned_identity.this.principal_id
  principal_type       = "ServicePrincipal"
  role_definition_name = each.value.role_definition_name
  scope                = each.value.scope
  condition            = each.value.condition
  condition_version    = each.value.condition != null ? coalesce(each.value.condition_version, "2.0") : null
}
