# Teams ingestion receives Microsoft Graph's change notifications through your Event Hubs
# namespace: Microsoft Graph Change Tracking sends them, and Complexio - Backend reads them with
# its own credentials. The recipe gives Complexio - Backend its part. Microsoft Graph Change
# Tracking's Azure Event Hubs Data Sender belongs to the namespace, not to either registration,
# so it stays as you assigned it.
locals {
  teams_ingestion = var.features.teams_ingestion_where_installed || var.features.teams_ingestion_tenant_wide
}

# Lets Complexio - Backend read the namespace's change notifications. The namespace may be in
# another subscription than the Key Vault: a role assignment is made at the scope it names.
resource "azurerm_role_assignment" "backend_event_hubs_receiver" {
  count = local.teams_ingestion ? 1 : 0

  scope                = var.event_hub_namespace_id
  role_definition_name = "Azure Event Hubs Data Receiver"
  principal_id         = azuread_service_principal.backend.object_id
  description          = "Lets Complexio - Backend read Microsoft Graph's change notifications for Teams ingestion."

  # Set so a Role Based Access Control Administrator constrained to service principals can assign
  # it, and so a just-created Complexio - Backend isn't refused before it has replicated.
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
