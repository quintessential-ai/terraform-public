# The ID of the scope Complexio - Backend exposes, generated once.
resource "random_uuid" "backend_access_as_user" {}

# The registration Complexio's services use to reach Microsoft 365, with the application
# permissions of the features you switch on, and the delegated ones Stevie uses as the signed-in
# user. It also asks for mail drafting and sending unless those switches are false, for an Entra
# administrator to approve; the install itself never grants them. It exposes one scope,
# access_as_user, which Complexio - SSO asks for to reach Microsoft 365 as the signed-in user.
# Admins and users may consent to it, but nobody is asked: Complexio - SSO is pre-authorized for
# it, and consented for everyone in sso.tf.
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
    for_each = length(setunion(local.known_application_permissions, local.backend_requested_delegated_permissions)) > 0 ? [data.azuread_service_principal.msgraph.client_id] : []
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
        for_each = local.backend_requested_delegated_permissions
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

# Complexio - Backend's tenant-wide Microsoft Graph grant as it stands, read whenever the install
# holds one. An approval writes into this same grant, so the grant below keeps the approvable mail
# write it finds here, and the check after it warns about approved mail write the configuration
# removes. It is read at plan time, except when the same apply creates or replaces Complexio -
# Backend's service principal (a first install), when it is read during the apply: an approval
# given between a plan read and its apply is not seen, and an apply that changes the grant removes
# it.
#
# Right after a first install creates Complexio - Backend, Microsoft Graph may not know it yet, so
# the read retries Graph's "not found" (Request_ResourceNotFound, whose message says the object
# "does not exist"), for at most the read timeout. A missing `scope` export (a query the provider
# failed to evaluate) stops the plan rather than reading as "nothing approved", which would remove
# every approval.
data "msgraph_resource" "backend_graph_grant" {
  count = length(local.known_backend_delegated_permissions) > 0 ? 1 : 0

  url = "servicePrincipals/${azuread_service_principal.backend.object_id}/oauth2PermissionGrants"
  response_export_values = {
    scope = "value[?consentType=='AllPrincipals' && resourceId=='${data.azuread_service_principal.msgraph.object_id}'] | [0].scope"
  }

  retry = {
    error_message_regex = ["Request_ResourceNotFound", "does not exist"]
  }

  timeouts {
    read = "3m"
  }
}

locals {
  # null when there is no grant to read, or no tenant-wide grant yet.
  backend_granted_scope      = one([for grant in data.msgraph_resource.backend_graph_grant : grant.output.scope])
  backend_granted_scopes     = toset(compact(split(" ", local.backend_granted_scope == null ? "" : local.backend_granted_scope)))
  approved_mail_write_scopes = setintersection(local.approvable_mail_write, local.backend_granted_scopes)
  # Stevie sends only drafts it wrote, so Mail.Send is kept only alongside Mail.ReadWrite.
  approved_mail_write  = contains(local.approved_mail_write_scopes, "Mail.ReadWrite") ? local.approved_mail_write_scopes : setsubtract(local.approved_mail_write_scopes, ["Mail.Send"])
  backend_grant_claims = setunion(local.known_backend_delegated_permissions, local.approved_mail_write)
  # Approved mail write the grant below drops. The check after it reports it when a switch is false.
  removed_mail_write = setsubtract(setintersection(local.mail_write_permissions, local.backend_granted_scopes), local.approved_mail_write)
}

# Admin consent for Complexio - Backend's delegated permissions, when any feature needs them, plus
# the mail write an administrator approved. Anything else added outside the install is removed.
# `count` depends on the configuration only, so a first install, whose grant can't be read until
# Complexio - Backend exists, still plans.
resource "azuread_service_principal_delegated_permission_grant" "backend_graph" {
  count = length(local.known_backend_delegated_permissions) > 0 ? 1 : 0

  service_principal_object_id          = azuread_service_principal.backend.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = local.backend_grant_claims
}

# A warning, not an error: false is how you remove mail write on purpose. It names the approval
# that a false copied from an earlier example would otherwise remove without notice. Without a
# false switch the condition holds before the grant is read, so a first install isn't warned that
# the result is known only after apply.
check "mail_write_approval_kept" {
  assert {
    condition     = !contains(values(local.mail_write_switches), false) || length(local.removed_mail_write) == 0
    error_message = "Complexio - Backend's grant holds mail write an Entra administrator approved, which this configuration removes: ${join(", ", sort(local.removed_mail_write))}. To keep it, remove stevie_mail_drafting_delegated = false and stevie_mail_sending_delegated = false."
  }
}
