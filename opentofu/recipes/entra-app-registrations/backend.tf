# The ID of the scope Complexio - Backend exposes, generated once.
resource "random_uuid" "backend_access_as_user" {}

# The registration Complexio's services use to reach Microsoft 365, with the application
# permissions of the features you switch on, and the delegated ones for drafting and sending mail
# from Stevie. It exposes one scope, access_as_user, which
# Complexio - SSO asks for to reach Microsoft 365 as the signed-in user. Admins and users may
# consent to it, but nobody is asked: Complexio - SSO is pre-authorized for it, and consented for
# everyone in sso.tf.
#
# Later applies leave its owners and notes, and its marketing, privacy, support and terms URLs, as
# you set them. The application ID URI is set by the next resource, since it contains the client
# ID. A plan stops if Microsoft Graph doesn't know one of the permissions.
resource "azuread_application" "backend" {
  display_name            = var.display_names.backend
  description             = local.backend_description
  notes                   = local.backend_notes
  logo_image              = local.logo
  sign_in_audience        = "AzureADMyOrg"
  prevent_duplicate_names = false

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      id                         = random_uuid.backend_access_as_user.result
      value                      = "access_as_user"
      type                       = "User"
      admin_consent_display_name = "Access Microsoft 365 as the signed-in user"
      admin_consent_description  = "Lets Complexio reach Microsoft 365 as the signed-in user, limited to what that user can already see."
      user_consent_display_name  = "Access Microsoft 365 as you"
      user_consent_description   = "Lets Complexio reach Microsoft 365 as you, limited to what you can already see."
    }
  }

  dynamic "required_resource_access" {
    for_each = length(setunion(local.known_application_permissions, local.known_backend_delegated_permissions)) > 0 ? [data.azuread_service_principal.msgraph.client_id] : []
    content {
      resource_app_id = required_resource_access.value

      dynamic "resource_access" {
        for_each = local.known_application_permissions
        content {
          id   = local.graph_role_ids[resource_access.value]
          type = "Role"
        }
      }

      dynamic "resource_access" {
        for_each = local.known_backend_delegated_permissions
        content {
          id   = local.graph_scope_ids[resource_access.value]
          type = "Scope"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      identifier_uris, owners, notes, tags, feature_tags, service_management_reference,
      marketing_url, privacy_statement_url, support_url, terms_of_service_url,
    ]

    precondition {
      condition     = length(local.unknown_application_permissions) == 0
      error_message = "Microsoft Graph has no application permission named ${join(", ", local.unknown_application_permissions)}."
    }

    precondition {
      condition     = length(local.unknown_delegated_permissions) == 0
      error_message = "Microsoft Graph has no delegated permission named ${join(", ", local.unknown_delegated_permissions)}."
    }
  }
}

# Complexio - Backend's application ID URI, api://<client-id>.
resource "azuread_application_identifier_uri" "backend" {
  application_id = azuread_application.backend.id
  identifier_uri = "api://${azuread_application.backend.client_id}"
}

# Lets Complexio - SSO ask for access_as_user without anyone being asked to consent.
resource "azuread_application_pre_authorized" "sso" {
  application_id       = azuread_application.backend.id
  authorized_client_id = azuread_application.sso.client_id
  permission_ids       = [random_uuid.backend_access_as_user.result]
}

# Complexio - Backend's enterprise application, listed under Enterprise applications. Later
# applies leave its owners, notes, notification addresses, visibility and whether sign-in is
# enabled as you set them.
resource "azuread_service_principal" "backend" {
  client_id   = azuread_application.backend.client_id
  description = local.backend_description

  feature_tags {
    enterprise = true
  }

  lifecycle {
    ignore_changes = [
      owners, notes, notification_email_addresses, login_url, preferred_single_sign_on_mode,
      tags, feature_tags, features, account_enabled,
    ]
  }
}

# Admin consent for Complexio - Backend's application permissions. It has no users of its own who
# could consent.
resource "azuread_app_role_assignment" "backend_graph" {
  for_each = local.known_application_permissions

  app_role_id         = local.graph_role_ids[each.value]
  principal_object_id = azuread_service_principal.backend.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# Admin consent for Complexio - Backend's delegated permissions, when any feature needs them.
resource "azuread_service_principal_delegated_permission_grant" "backend_graph" {
  count = length(local.known_backend_delegated_permissions) > 0 ? 1 : 0

  service_principal_object_id          = azuread_service_principal.backend.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = local.known_backend_delegated_permissions
}
