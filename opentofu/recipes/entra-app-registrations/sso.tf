# The IDs of the two scopes Complexio - SSO exposes, generated once.
resource "random_uuid" "sso_access" {}

resource "random_uuid" "sso_access_as_user" {}

# Where Microsoft Entra may send users back to after sign-in and sign-out, on each of your hosts.
# Entra doesn't accept the same address on both the web and the single-page application platform,
# so each address is on one of them only.
locals {
  sso_web_redirect_uris = flatten([
    for host in var.browser_hosts : ["https://${host}/auth/callback", "https://${host}/login"]
  ])
  sso_spa_redirect_uris = distinct(concat(
    flatten([for host in var.browser_hosts : [
      for path in ["/", "/cpx-support", "/stevie/", "/oauth/callback", "/stevie/chat", "/settings/", "/eav2/", "/task-board/"] :
      "https://${host}${path}"
    ]]),
    [for host in var.mcp_hosts : "https://${host}/oauth/callback"],
  ))
}

# The registration your users sign in to Stevie, Settings and Enterprise Automator with.
#
# Its tokens carry only the groups assigned to its enterprise application, as object IDs, which is
# how Complexio knows which access groups a user is in. It exposes two scopes for Complexio's own
# applications, and asks for the sign-in permissions, the delegated permissions of the features
# you switch on, and Complexio - Backend's access_as_user.
#
# Later applies leave its owners and notes, and its marketing, privacy, support and terms URLs, as
# you set them. The application ID URI is set by the next resource, since it contains the client
# ID.
resource "azuread_application" "sso" {
  display_name            = var.display_names.sso
  description             = local.sso_description
  logo_image              = local.logo
  sign_in_audience        = "AzureADMyOrg"
  prevent_duplicate_names = false
  group_membership_claims = ["ApplicationGroup"]

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      id                         = random_uuid.sso_access.result
      value                      = "access"
      type                       = "Admin"
      admin_consent_display_name = "Use Complexio"
      admin_consent_description  = "Lets Complexio's applications call Complexio's services for the signed-in user."
    }

    oauth2_permission_scope {
      id                         = random_uuid.sso_access_as_user.result
      value                      = "access_as_user"
      type                       = "Admin"
      admin_consent_display_name = "Use Complexio as the signed-in user"
      admin_consent_description  = "Lets Complexio's services act as the signed-in user, limited to what that user can already do in Complexio."
    }
  }

  optional_claims {
    id_token {
      name = "groups"
    }
    access_token {
      name = "groups"
    }
    access_token {
      name = "preferred_username"
    }
    access_token {
      name = "email"
    }
    saml2_token {
      name = "groups"
    }
  }

  web {
    redirect_uris = local.sso_web_redirect_uris
  }

  single_page_application {
    redirect_uris = local.sso_spa_redirect_uris
  }

  required_resource_access {
    resource_app_id = data.azuread_service_principal.msgraph.client_id

    dynamic "resource_access" {
      for_each = setunion(local.known_sign_in_permissions, local.known_sso_delegated_permissions)
      content {
        id   = local.graph_scope_ids[resource_access.value]
        type = "Scope"
      }
    }
  }

  required_resource_access {
    resource_app_id = azuread_application.backend.client_id

    resource_access {
      id   = random_uuid.backend_access_as_user.result
      type = "Scope"
    }
  }

  lifecycle {
    ignore_changes = [
      identifier_uris, owners, notes, tags, feature_tags, service_management_reference,
      marketing_url, privacy_statement_url, support_url, terms_of_service_url,
    ]
  }
}

# Complexio - SSO's application ID URI, api://<client-id>.
resource "azuread_application_identifier_uri" "sso" {
  application_id = azuread_application.sso.id
  identifier_uri = "api://${azuread_application.sso.client_id}"
}

# Complexio - SSO's enterprise application. Only the users and groups assigned to it can sign in;
# which ones is yours to choose, here or with the access groups in access-groups.tf. Later applies
# leave its owners, notes, notification addresses, visibility and whether sign-in is enabled as
# you set them.
resource "azuread_service_principal" "sso" {
  client_id                    = azuread_application.sso.client_id
  description                  = local.sso_description
  app_role_assignment_required = true

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

# Admin consent for Complexio - SSO's permissions, so users aren't asked when they first sign in.
# Microsoft Entra requires an administrator's consent anyway, because assignment is required.
resource "azuread_service_principal_delegated_permission_grant" "sso_graph" {
  service_principal_object_id          = azuread_service_principal.sso.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = setunion(local.known_sign_in_permissions, local.known_sso_delegated_permissions)
}

# Admin consent for Complexio - SSO to use Complexio - Backend's access_as_user, for everyone in
# your organization, so the API permissions page shows it as granted.
resource "azuread_service_principal_delegated_permission_grant" "sso_backend" {
  service_principal_object_id          = azuread_service_principal.sso.object_id
  resource_service_principal_object_id = azuread_service_principal.backend.object_id
  claim_values                         = ["access_as_user"]
}
