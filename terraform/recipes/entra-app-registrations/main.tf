# The two app registrations Complexio runs with in your tenant: Complexio - SSO, which your users
# sign in with, and Complexio - Backend, which Complexio's services use to reach Microsoft 365.
# Their credentials and IDs are written to your Key Vault.
#
# Each part is in its own file: permissions.tf, branding.tf, backend.tf, sso.tf, client-secrets.tf,
# certificates.tf, key-vault.tf, access-groups.tf and mailbox-access.tf.

# The tenant being configured, whose ID Complexio's services sign in against.
data "azuread_client_config" "current" {}

# Microsoft Graph in your tenant, which holds the IDs of the permissions this recipe grants.
data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}
