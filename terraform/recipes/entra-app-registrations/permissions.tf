# The Microsoft Graph permissions each feature in var.features needs, with what each is for.
#
# Application permissions are used by Complexio's services without a signed-in user, and are
# granted to Complexio - Backend. Mailbox access is not among them: it is granted in Exchange
# Online, limited to the mailboxes you choose (see mailbox-access.tf). With
# teams_ingestion_where_installed, Teams access covers only the chats and teams the Complexio
# Assistant Teams app is installed in, and reading their messages comes from the permissions the
# app asks for when you install it. teams_ingestion_tenant_wide grants channel access tenant-wide
# instead, so Microsoft Graph lets Complexio read every team's channels; chats aren't included.
#
# Delegated permissions are used as the signed-in user, never reaching further than what that
# user can already see. Stevie's are granted to Complexio - SSO. Complexio - Backend gets only
# those for drafting and sending mail as the user from Stevie: every Microsoft Graph token it gets
# for a user carries all of its delegated permissions, and its mail drafting accepts no others.
#
# Every sign-in also needs openid, profile, email and offline_access to identify the user and keep
# them signed in, and User.Read to read their profile.
locals {
  application_permissions_by_feature = {
    email_ingestion = {
      "User.Read.All"         = "Find the mailboxes to ingest (GET /users)."
      "GroupMember.Read.All"  = "Read the members of a group whose mailboxes are ingested (GET /groups/{id}/members)."
      "Organization.Read.All" = "Check that the credentials work (GET /organization)."
    }
    teams_ingestion_where_installed = {
      "Chat.Read.WhereInstalled" = "Read the messages of chats the Complexio Assistant is installed in, and be notified of new ones (GET /chats/{id}/messages, POST /subscriptions)."
      "AppCatalog.Read.All"      = "Find Complexio's Teams app in your app catalog (GET /appCatalogs/teamsApps)."
      "Group.ReadBasic.All"      = "List the teams in the tenant by name, to find the ones the app is installed in (GET /groups)."
      "Team.ReadBasic.All"       = "Read a team's name and description (GET /teams/{id})."
      "Channel.ReadBasic.All"    = "List a team's channels by name (GET /teams/{id}/channels)."
      "Organization.Read.All"    = "Check that the credentials work (GET /organization)."
    }
    teams_ingestion_tenant_wide = {
      "AppCatalog.Read.All"                  = "Find Complexio's Teams app in your app catalog (GET /appCatalogs/teamsApps)."
      "Group.ReadBasic.All"                  = "List the teams in the tenant by name (GET /groups)."
      "Team.ReadBasic.All"                   = "Read a team's name and description (GET /teams/{id})."
      "Channel.ReadBasic.All"                = "List a team's channels by name (GET /teams/{id}/channels)."
      "TeamsAppInstallation.ReadForTeam.All" = "Find the teams the Complexio Assistant is installed in (GET /teams/{id}/installedApps)."
      "TeamsTab.Read.All"                    = "Find the channels it is added to (GET /teams/{id}/channels/{id}/tabs)."
      "ChannelMessage.Read.All"              = "Read those channels' messages and replies (GET /teams/{id}/channels/{id}/messages/delta)."
      "Organization.Read.All"                = "Check that the credentials work (GET /organization)."
    }
    settings_directory = {
      "User.Read.All"       = "List enabled users and their departments in Settings (GET /users)."
      "Group.ReadBasic.All" = "List security groups by name to choose from in Settings (GET /groups)."
    }
    usage_metrics = {
      "User.Read.All" = "Look up a user to report usage by department (GET /users/{id})."
    }
  }

  sso_delegated_permissions_by_feature = {
    stevie_mail_delegated = {
      "Mail.Read" = "Read the user's mail folders, messages and attachments (GET /me/mailFolders, GET /me/messages)."
      "Mail.Send" = "Send mail, and send drafts, as the user (POST /me/sendMail, POST /me/messages/{id}/send)."
    }
    stevie_calendar_delegated = {
      "Calendars.Read" = "Read the user's events and check attendees' free/busy times (GET /me/calendarView, POST /me/calendar/getSchedule)."
    }
    stevie_onedrive_delegated = {
      "Files.Read" = "Browse, search and read the user's OneDrive (GET /me/drive)."
    }
    stevie_people_delegated = {
      "People.Read" = "Search people in your organization (GET /me/people)."
    }
    stevie_meetings_delegated = {
      "OnlineMeetings.Read"              = "Find an online meeting by its join link (GET /me/onlineMeetings)."
      "OnlineMeetingTranscript.Read.All" = "Read a meeting's transcripts (GET /me/onlineMeetings/{id}/transcripts)."
    }
    stevie_teams_delegated = {
      "Team.ReadBasic.All"      = "List the user's teams (GET /me/joinedTeams)."
      "Channel.ReadBasic.All"   = "List a team's channels (GET /teams/{id}/channels)."
      "ChannelMessage.Read.All" = "Read and search channel messages (GET /teams/{id}/channels/{id}/messages, POST /search/query)."
      "Chat.Read"               = "Read the user's chat messages (GET /me/chats/{id}/messages)."
      "Chat.ReadBasic"          = "List the user's chats and their names (GET /me/chats)."
    }
    stevie_sharepoint_delegated = {
      "Sites.Read.All" = "Find and search the SharePoint sites, lists and list items the user can open (GET /sites, POST /search/query)."
      "Files.Read.All" = "List and read the files in SharePoint document libraries the user can open (GET /sites/{id}/drives, GET /drives/{id}/root/children)."
    }
  }

  backend_delegated_permissions_by_feature = {
    stevie_mail_drafting_delegated = {
      "Mail.ReadWrite" = "Create reply and forward drafts, and edit them, as the user (POST /me/messages/{id}/createReply, PATCH /me/messages/{id})."
    }
    stevie_mail_sending_delegated = {
      "Mail.Send" = "Send a draft the user approved, as the user (POST /me/messages/{id}/send)."
    }
  }

  application_permissions = setunion(var.additional_application_permissions, flatten([
    for feature, permissions in local.application_permissions_by_feature : keys(permissions) if var.features[feature]
  ]))
  sso_delegated_permissions = toset(flatten([
    for feature, permissions in local.sso_delegated_permissions_by_feature : keys(permissions) if var.features[feature]
  ]))
  backend_delegated_permissions = toset(flatten([
    for feature, permissions in local.backend_delegated_permissions_by_feature : keys(permissions) if var.features[feature]
  ]))
  sign_in_permissions = toset(["openid", "profile", "email", "offline_access", "User.Read"])

  graph_role_ids  = data.azuread_service_principal.msgraph.app_role_ids
  graph_scope_ids = data.azuread_service_principal.msgraph.oauth2_permission_scope_ids

  unknown_application_permissions     = setsubtract(local.application_permissions, keys(local.graph_role_ids))
  unknown_delegated_permissions       = setsubtract(setunion(local.sso_delegated_permissions, local.backend_delegated_permissions, local.sign_in_permissions), keys(local.graph_scope_ids))
  known_application_permissions       = setsubtract(local.application_permissions, local.unknown_application_permissions)
  known_sso_delegated_permissions     = setsubtract(local.sso_delegated_permissions, local.unknown_delegated_permissions)
  known_backend_delegated_permissions = setsubtract(local.backend_delegated_permissions, local.unknown_delegated_permissions)
  known_sign_in_permissions           = setsubtract(local.sign_in_permissions, local.unknown_delegated_permissions)
}
