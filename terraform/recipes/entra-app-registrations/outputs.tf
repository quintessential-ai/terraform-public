output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "sso_client_id" {
  description = "Application (client) ID of Complexio - SSO."
  value       = azuread_application.sso.client_id
}

output "backend_client_id" {
  description = "Application (client) ID of Complexio - Backend."
  value       = azuread_application.backend.client_id
}

output "key_vault_entries" {
  description = "What was written to Key Vault, by entry name."
  value = merge(
    { for key, certificate in azurerm_key_vault_certificate.this : certificate.name => {
      sso     = "Complexio - SSO's certificate and private key, as PEM."
      backend = "Complexio - Backend's certificate and private key, as PEM."
    }[key] },
    { for key, secret in azurerm_key_vault_secret.this : secret.name => {
      TENANT-ID           = "Your tenant ID."
      SSO-CLIENT-ID       = "Complexio - SSO's client ID."
      SSO-CHAT-API-SECRET = "Complexio - SSO's client secret for Stevie Chat API."
      SSO-GATEWAY-SECRET  = "Complexio - SSO's client secret for Stevie Gateway."
      BACKEND-CLIENT-ID   = "Complexio - Backend's client ID."
      BACKEND-SECRET      = "Complexio - Backend's client secret."
    }[key] },
  )
}

output "credential_expiry" {
  description = "When each credential expires. Renew it before then."
  value = {
    sso_chat_api_secret = azuread_application_password.sso_chat_api.end_date
    sso_gateway_secret  = azuread_application_password.sso_gateway.end_date
    backend_secret      = azuread_application_password.backend.end_date
    sso_certificate     = azuread_application_certificate.this["sso"].end_date
    backend_certificate = azuread_application_certificate.this["backend"].end_date
  }
}

output "group_object_ids" {
  description = "Object ID of each access group, by name. Share these with Complexio: they are how Settings refers to the groups."
  value       = { for name, group in azuread_group.access : name => group.object_id }
}

output "application_permissions" {
  description = "Microsoft Graph application permissions granted to Complexio - Backend."
  value       = sort(local.known_application_permissions)
}

output "sso_delegated_permissions" {
  description = "Microsoft Graph delegated permissions granted to Complexio - SSO, besides sign-in."
  value       = sort(local.known_sso_delegated_permissions)
}

output "backend_delegated_permissions" {
  description = "Microsoft Graph delegated permissions granted to Complexio - Backend."
  value       = sort(local.known_backend_delegated_permissions)
}

output "mailbox_administrative_unit_id" {
  description = "Object ID of the \"Complexio mailboxes\" administrative unit. Add the users whose mailboxes Complexio may reach to it."
  value       = azuread_administrative_unit.mailboxes.object_id
}

output "exchange_mailbox_access_commands" {
  description = "Exchange Online PowerShell that grants Complexio - Backend mailbox access, limited to the \"Complexio mailboxes\" administrative unit. Run it once as an Exchange Administrator; Complexio can't read or send mail until you do."
  value = length(local.exchange_mail_roles) == 0 ? null : join("\n", concat(
    [
      "# Requires the ExchangeOnlineManagement module: Install-Module ExchangeOnlineManagement",
      "Connect-ExchangeOnline",
      "",
      "# Tell Exchange about Complexio - Backend. The IDs are its enterprise application's.",
      "New-ServicePrincipal -AppId ${azuread_application.backend.client_id} -ObjectId ${azuread_service_principal.backend.object_id} -DisplayName \"${var.display_names.backend}\"",
      "",
      "# Grant mailbox access for the members of the \"Complexio mailboxes\" administrative unit only.",
    ],
    [for role in local.exchange_mail_roles :
      "New-ManagementRoleAssignment -App ${azuread_service_principal.backend.object_id} -Role \"${role}\" -RecipientAdministrativeUnitScope ${azuread_administrative_unit.mailboxes.object_id}"
    ],
    [
      "",
      "# Check: InScope is True for a mailbox in the unit and False for any other.",
      "# Changes take from 30 minutes to 2 hours to apply; this check sees them at once.",
      "Test-ServicePrincipalAuthorization -Identity ${azuread_service_principal.backend.object_id} -Resource <mailbox address>",
    ],
  ))
}
