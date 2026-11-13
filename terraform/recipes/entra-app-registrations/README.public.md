# entra-app-registrations

Creates the Microsoft Entra app registrations Complexio runs with in your tenant, grants the
Microsoft Graph permissions for the features you choose, and writes their credentials to your
Key Vault. Your directory administrator applies it; Complexio never needs write access to your
directory.

## What gets created

| In Microsoft Entra | What it is for |
| --- | --- |
| **Complexio - SSO** app registration and enterprise application | Sign-in to Stevie, Settings and Enterprise Automator, and from Claude to the Context Broker. Only the users and groups assigned to the enterprise application can sign in, and tokens carry only those groups. |
| **Complexio - Backend** app registration and enterprise application | What Complexio's services use to reach Microsoft 365, with the permissions of the features you switch on. |
| Admin consent for both | So users aren't asked to consent when they first sign in. |
| **Complexio mailboxes** administrative unit | The mailboxes Complexio may reach. See [Mailbox access](#mailbox-access). |
| Access groups (unless `create_and_assign_access_groups` is off) | Security groups, assigned to Complexio - SSO. See [Access groups](#access-groups). |

| In your Key Vault, under `<key_vault_secret_prefix>--` | Holds |
| --- | --- |
| `CPX-TENANT-ID` | Your tenant ID |
| `CPX-SSO-CLIENT-ID` | Complexio - SSO's client ID |
| `CPX-SSO-CHAT-API-SECRET`, `CPX-SSO-GATEWAY-SECRET` | Complexio - SSO's two client secrets, until Stevie signs in with the certificate |
| `CPX-SSO-CERTIFICATE` | Complexio - SSO's certificate and private key |
| `CPX-BACKEND-CLIENT-ID` | Complexio - Backend's client ID |
| `CPX-BACKEND-SECRET` | Complexio - Backend's client secret |
| `CPX-BACKEND-CERTIFICATE` | Complexio - Backend's certificate and private key |

| In Azure | What it is for |
| --- | --- |
| **Azure Event Hubs Data Receiver** for Complexio - Backend on your Event Hubs namespace, with Teams ingestion | Reading the Teams change notifications Microsoft Graph sends there. See [Teams ingestion](#teams-ingestion). |

Each certificate is generated in the vault. Only its public part is registered in Microsoft
Entra; Complexio's services read the key from here.

Nothing leaves your tenant. Complexio's services read these entries from the vault.

## Before you start

- **Roles.** Apply as a **Global Administrator** for now; a narrower set of roles is being
  confirmed. On the Key Vault you also need **Key Vault Certificates Officer** and
  **Key Vault Secrets Officer**: `complexio-cluster` grants both to the groups in its
  `key_vault_secrets_officer_groups`, so be in one of them. The
  [Mailbox access](#mailbox-access) step needs an **Exchange Administrator**. With Teams
  ingestion, you also need **Role Based Access Control Administrator** on the Event Hubs
  namespace (Owner or User Access Administrator also work, but grant more); see
  [Teams ingestion](#teams-ingestion).
- **The Key Vault that `complexio-cluster` creates.** Apply that recipe first.
- **The host names** your users open Complexio on. Complexio confirms them with you.
- **Terraform or OpenTofu**, at the versions in
  [How can I use it?](../../README.public.md#how-can-i-use-it), and the Azure CLI signed in to
  your tenant (`az login --tenant <tenant_id>`).
- **A remote backend for the state**, as for every recipe. See
  [How can I use it?](../../README.public.md#how-can-i-use-it).

## Inputs

Run the recipe like the others, from `//terraform/recipes/entra-app-registrations`. With
Terragrunt, the [example](../../README.public.md#consuming-it-via-terragrunt-golden-path) reads
`tenant_id`, `subscription_id` and `key_vault_id` from the outputs of `complexio-cluster`. The
inputs it needs are:

```hcl
# key_vault_id is the key_vault_id output of complexio-cluster.
tenant_id       = "<tenant_id>"
subscription_id = "<subscription_id of the Key Vault>"
key_vault_id    = "<key_vault_id>"
browser_hosts   = ["complexio.example.com"]
```

<details>
<summary>A fuller example</summary>

```hcl
# key_vault_id is the key_vault_id output of complexio-cluster.
tenant_id       = "<tenant_id>"
subscription_id = "<subscription_id of the Key Vault>"
key_vault_id    = "<key_vault_id>"

# Host names your users open Complexio on. Complexio confirms them with you.
browser_hosts = ["complexio.example.com"]
# MCP server host names, if you use them.
mcp_hosts = []

# What Complexio may do in your Microsoft 365 tenant. Switch off anything you have not agreed with
# Complexio; a switch left out keeps the default shown here.
features = {
  # Without a signed-in user.
  email_ingestion                 = true  # Ingest the mailboxes you choose. Also run the Exchange step, see the README.
  teams_ingestion_where_installed = false # Ingest only the chats and teams you install the Complexio Assistant app in.
  teams_ingestion_tenant_wide     = false # Ingest the app's channels with tenant-wide permissions. Only if Complexio asks.
  settings_directory              = true  # List users, departments and security groups in Settings.
  automator_email                 = false # Let Enterprise Automator draft and send mail. Also run the Exchange step.
  usage_metrics                   = true  # Report usage by department.

  # As the signed-in user, limited to what that user can already see.
  stevie_mail_delegated       = true
  stevie_calendar_delegated   = true
  stevie_onedrive_delegated   = true
  stevie_people_delegated     = true
  stevie_meetings_delegated   = true
  stevie_teams_delegated      = true
  stevie_sharepoint_delegated = true

  # Mail drafting and sending: left out, Complexio - Backend asks for them and an Entra
  # administrator approves them; the install never grants them. false removes them. See the README.
  # stevie_mail_drafting_delegated = false
  # stevie_mail_sending_delegated  = false
}

# With either Teams ingestion switch: the Event Hubs namespace Microsoft Graph sends Teams change
# notifications to. It may be in another subscription than the Key Vault.
# event_hub_namespace_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.EventHub/namespaces/complexio-msgraph"

# Create Complexio's standard access groups and assign them to Complexio - SSO.
create_and_assign_access_groups = true
# Names the groups <prefix>-owners, <prefix>-ea and so on.
access_group_name_prefix = "complexio"
# One Stevie access group per department, named complexio-stevie-<department>.
stevie_departments = []

tags = {}
```

</details>

[`variables.tf`](variables.tf) describes every input. `key_vault_secret_prefix` (`deployments` by
default) starts the name of every Key Vault entry.

The commands below use `terraform`; with Terragrunt, run the same ones with `terragrunt`:

```bash
terraform init
terraform plan
terraform apply
```

Apply right after planning: see [Mail drafting and sending](#mail-drafting-and-sending) for why a
saved plan applied later can remove a mail approval.

The plan lists every permission it grants. `terraform output application_permissions`,
`sso_delegated_permissions` and `backend_delegated_permissions` show them again after apply, and
`backend_requested_delegated_permissions` what Complexio - Backend asks for, mail write included.

## Features

Each switch in `features` grants the Microsoft Graph permissions one feature needs, and nothing
is granted for a switch that is off. Switch off anything you have not agreed with Complexio:
the `stevie_*` switches are on by default. Mail drafting and sending are the exception: the
install asks for them but never grants them, and an Entra administrator approves them.

| Switch | Default | What it lets Complexio do |
| --- | --- | --- |
| `email_ingestion` | on | Ingest the mailboxes you choose. Needs the [Mailbox access](#mailbox-access) step. |
| `teams_ingestion_where_installed` | off | Ingest only the chats and teams you install the Complexio Assistant Teams app in. Nothing else is reachable. Needs `event_hub_namespace_id` and the [Teams ingestion](#teams-ingestion) steps. |
| `teams_ingestion_tenant_wide` | off | Ingest the channels you install the Complexio Assistant Teams app in, with tenant-wide permissions instead of the app's own. Microsoft Graph then lets Complexio read every team's channels. Chats aren't included. Switch it on only if Complexio asks you to. Needs `event_hub_namespace_id` and the [Teams ingestion](#teams-ingestion) steps. |
| `settings_directory` | on | List users, departments and security groups in Settings. |
| `automator_email` | off | Let Enterprise Automator draft and send mail from the mailboxes you choose. Needs the [Mailbox access](#mailbox-access) step. |
| `usage_metrics` | on | Report usage by department. |
| `stevie_mail_delegated` | on | Let Stevie read the signed-in user's mail. |
| `stevie_calendar_delegated` | on | Let Stevie read the signed-in user's calendar and check attendees' availability. |
| `stevie_onedrive_delegated` | on | Let Stevie browse and read the signed-in user's OneDrive. |
| `stevie_people_delegated` | on | Let Stevie search people in your organization. |
| `stevie_meetings_delegated` | on | Let Stevie find meetings and read their transcripts. |
| `stevie_teams_delegated` | on | Let Stevie read the signed-in user's teams, channels and chats. |
| `stevie_sharepoint_delegated` | on | Let Stevie search and read the SharePoint sites, lists and files the signed-in user can open. |
| `stevie_mail_drafting_delegated` | requested, kept once approved | Let Stevie write reply and forward drafts in the signed-in user's mailbox. Leave it out, or set `false` to stop asking for it; `true` is refused. See [Mail drafting and sending](#mail-drafting-and-sending). |
| `stevie_mail_sending_delegated` | requested, kept once approved | Let Stevie send the drafts the signed-in user approves. Leave it out, or set `false` to stop asking for it; `true` is refused. Removed with drafting. |

Switches ending in `_delegated` act as the signed-in user, so they never reach further than what
that user can already see. They are granted to Complexio - Backend, and to Complexio - SSO as
well, except mail drafting and sending, which only Complexio - Backend asks for. The others work
without a signed-in user.
[`permissions.tf`](permissions.tf) lists each permission with what it is needed for.

`additional_application_permissions` adds further application permissions by name, if Complexio
asks for them. It refuses mailbox, calendar and contact permissions, which would reach every
mailbox in your tenant.

### Mail drafting and sending

Whether Stevie may write and send mail as the user is your Entra administrator's decision, not the
install's. The install never grants it. With both switches left out, Complexio - Backend asks for
the delegated `Mail.ReadWrite` and `Mail.Send` permissions, and under **API permissions** in
Microsoft Entra they show as requested, not granted. An Entra administrator approves them from
the link in Complexio Settings, or with **Grant admin consent** on Complexio - Backend's
**API permissions** page. Every later `apply` keeps that approval.

They act only as the signed-in user, so they reach that user's own mailbox and nothing else, and
Complexio - SSO never holds them. They need no [Mailbox access](#mailbox-access) step: that one
governs application access to the mailboxes you list, while this is the signed-in user's own
mailbox.

- **Drafting only.** **Grant admin consent** approves drafting and sending together. To allow
  drafting only, set `stevie_mail_sending_delegated = false`: Complexio - Backend then asks for
  `Mail.ReadWrite` alone, and the next `apply` removes an approved `Mail.Send`.
- **Removing it.** Set `stevie_mail_drafting_delegated = false`, which removes sending as well,
  since Stevie sends only drafts it has written, and `apply`. Complexio - Backend then no longer
  asks for mail write, and the apply removes the tenant-wide approval; `plan` and `apply` warn
  (`mail_write_approval_kept`) when a `false` switch removes an approval. Or revoke the admin
  consent for `Mail.ReadWrite` and `Mail.Send` on the **API permissions** page: later applies don't
  add it back. An approved `Mail.Send` is kept only while `Mail.ReadWrite` is approved too.
- **Users' own consent.** Both permissions are ones users may consent to for themselves, if your
  tenant's user consent settings allow it. The install neither reads nor removes a user's own
  consent: it is listed under **Enterprise applications**, Complexio - Backend, **Permissions**,
  **User consent**, where **Review permissions** gives the commands that revoke it.
- **`true` is refused.** The plan stops if either switch is `true`. Remove the line to keep the
  approval your tenant already holds.
- **Apply right after planning.** `plan` reads which mail write is approved, and then lists it
  among the permissions it keeps. An approval given after the plan, and before its `apply` (for
  example with a plan saved by `plan -out` and applied later), is not seen, and if that `apply`
  changes Complexio - Backend's permissions it removes the approval. Approve again, or plan again
  first. Only a first install, which creates Complexio - Backend, reads the approval during the
  apply instead.
- **With every `stevie_*` reading switch off**, Complexio - Backend holds no delegated permission
  to keep an approval with, so it asks for no mail write either.

```hcl
features = {
  # ... the other switches ...
  stevie_mail_sending_delegated = false # Drafting only.
}
```

Reading the approval uses the `microsoft/msgraph` provider, which signs in through the Azure CLI
like the `azuread` provider, with no further setup.

## Upgrading

The reading switches and the access groups are now on by default, and mail drafting and sending
are off. The next `apply` of a configuration that omits them:

- Grants admin consent for the Stevie reading permissions only: none for `Mail.ReadWrite` or
  `Mail.Send`.
- Removes `Mail.Send` from Complexio - SSO, and `Mail.ReadWrite` and `Mail.Send` from
  Complexio - Backend, if your install holds them. The version of 27 October granted them by
  default; earlier versions left every `stevie_*` switch off and granted none. Stevie reads mail
  through Complexio - SSO and writes it through Complexio - Backend.
- Creates the standard access groups. If you already created groups such as `complexio-owners`
  by hand, the apply stops. Choose another `access_group_name_prefix` or opt out.

To keep the rest of the previous behaviour, set each `stevie_*` switch you don't want to `false`,
and set `create_and_assign_access_groups = false`.

Mail drafting and sending are now approved in Microsoft Entra, not switched on in the install; see
[Mail drafting and sending](#mail-drafting-and-sending). After upgrading:

- Remove any `stevie_mail_drafting_delegated = false` or `stevie_mail_sending_delegated = false`
  you copied from the earlier example, unless you mean to keep mail write out: `false` now means
  Complexio - Backend doesn't ask for it, so an administrator has nothing to approve, and the next
  `apply` removes an approval given from Complexio Settings. `plan` warns
  (`mail_write_approval_kept`) when it is about to.
- Remove any `stevie_mail_drafting_delegated = true` or `stevie_mail_sending_delegated = true`:
  the plan now stops on `true`.
- The next `apply` keeps whatever mail write your tenant holds, whether an administrator approved
  it or an earlier version of this install granted it. To remove it, set
  `stevie_mail_drafting_delegated = false` and `apply`, or revoke it in Microsoft Entra.
- If an `apply` stops because Complexio - Backend's Microsoft Graph grant already exists, the
  grant was created outside the install: an administrator approved mail write while every
  `stevie_*` switch was off, or revoked all of Complexio - Backend's admin consent and granted it
  again. Take the grant over once, then apply again:

  ```bash
  # Complexio - Backend's object ID, from its client ID, and its Microsoft Graph grant's ID.
  backend=$(az ad sp show --id "$(terraform output -raw backend_client_id)" --query id -o tsv)
  graph=$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query id -o tsv)
  grant=$(az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$backend/oauth2PermissionGrants" \
    --query "value[?consentType=='AllPrincipals' && resourceId=='$graph'] | [0].id" -o tsv)
  terraform import 'azuread_service_principal_delegated_permission_grant.backend_graph[0]' "/oauth2PermissionGrants/$grant"
  ```

  With OpenTofu, run `tofu` in place of `terraform`. If you call the recipe as a module, prefix
  the address with the module's, such as
  `module.complexio_entra_app_registrations.azuread_service_principal_delegated_permission_grant.backend_graph[0]`,
  and read `backend_client_id` from the module's output.

Complexio - SSO now asks for its own `access` scope, so Claude can sign in to the Context Broker,
and its API permissions are managed as separate resources. If you applied an earlier version,
Terraform must take over the two permissions it already has before the next `apply`, which
otherwise stops with "needs to be imported". Add a file next to your configuration with:

```hcl
import {
  to = azuread_application_api_access.sso_graph
  id = "${azuread_application.sso.id}/apiAccess/${data.azuread_service_principal.msgraph.client_id}"
}

import {
  to = azuread_application_api_access.sso_backend
  id = "${azuread_application.sso.id}/apiAccess/${azuread_application.backend.client_id}"
}
```

If you already listed Complexio - SSO's own `access` scope under its API permissions yourself,
add a third block for `azuread_application_api_access.sso_self`, with
`azuread_application.sso.client_id` in place of the API's client ID. Run `terraform plan` and
`terraform apply` as usual, then delete the file.

With a Teams ingestion switch on, the recipe now needs `event_hub_namespace_id` and gives
Complexio - Backend **Azure Event Hubs Data Receiver** on that namespace. If you already
assigned that role to this Complexio - Backend yourself, remove your assignment before the next
`apply`, which otherwise stops because it already exists. Without Teams ingestion, nothing
changes.

## Mailbox access

Microsoft Entra can only grant mailbox access for every mailbox in your tenant. Exchange Online
can grant it for chosen mailboxes only, so that is where `email_ingestion` and `automator_email`
grant it. This recipe never grants mailbox access in Entra: if it did, the Exchange scope would
have no effect, because Exchange adds the two together.

> **Don't add application mail permissions to Complexio - Backend in the Entra admin center.**
> Its API permissions show no application mail permission, and that is intended: mailbox access
> is in Exchange. The delegated mail permissions appear there only for the Stevie switches you
> turn on; they reach only the signed-in user's own mailbox. Adding `Mail.Read`, `Mail.ReadWrite`
> or `Mail.Send` as an application permission and granting admin consent would open every
> mailbox in your tenant. A later apply removes the permission from the list but not the consent,
> so revoke it yourself under the enterprise application's **Permissions** if it ever happens.

After `apply`:

1. In the Entra admin center, open the **Complexio mailboxes** administrative unit and add the
   users whose mailboxes Complexio may reach. Add the users themselves: a group added to an
   administrative unit doesn't bring its members in. Shared mailboxes work the same way: add the
   shared mailbox's own user, not the people who have access to it.
2. As an Exchange Administrator, run the PowerShell that
   `terraform output -raw exchange_mailbox_access_commands` prints. It needs the
   `ExchangeOnlineManagement` module.
3. Check one mailbox inside the unit and one outside it with `Test-ServicePrincipalAuthorization`,
   as the output shows. Changes take from 30 minutes to 2 hours to apply; the check sees them at
   once.

Complexio can't reach the mailboxes you choose until this is done. Users you add to the unit later
are in scope without running the commands again. If Complexio - Backend is ever recreated, Exchange
removes its grants with it: run the commands again from the new output.

Microsoft documents this in
[Role Based Access Control for Applications in Exchange Online](https://learn.microsoft.com/en-us/exchange/permissions-exo/application-rbac).

## Teams ingestion

Microsoft Graph sends Teams change notifications to an Event Hubs namespace in your Azure
subscription, and Complexio - Backend reads them there with its own credentials. With either
Teams ingestion switch on, set `event_hub_namespace_id` to the namespace's resource ID, shown on
its **Properties** page in the Azure portal. The namespace may be in another subscription than
the Key Vault: the recipe assigns the role at the namespace itself.

The recipe gives Complexio - Backend **Azure Event Hubs Data Receiver** on the namespace. Doing
so needs **Role Based Access Control Administrator** on the namespace, its resource group or its
subscription. You can limit that role assignment with a condition to assigning **Azure Event
Hubs Data Receiver** to service principals. Owner and User Access Administrator also work.

The recipe doesn't create the namespace or anything in it. Keep, or create as in Complexio's
Microsoft 365 ingestion guide:

- the namespace, by default `complexio-msgraph`
- its event hubs `subscription-lifecycle-notifications` and `change-notifications`, each with the
  consumer group `CpxIngestion`
- **Azure Event Hubs Data Sender** for **Microsoft Graph Change Tracking** on the namespace. It
  belongs to the namespace, not to Complexio's registrations, so the recipe leaves it as it is.

After `apply`:

1. Send Complexio the output of `terraform output teams_app_package`. Complexio builds the
   Complexio Assistant Teams app package with it: the package names Complexio - Backend's client
   ID, and Microsoft Teams grants the app's permissions in each chat and team to that
   registration only. A new Complexio - Backend, or a new client ID, needs a new package.
2. In the Microsoft Teams admin center, under **Teams apps** > **Manage apps**, upload the package
   Complexio gives you, as a new app or as a new version of the Complexio Assistant already
   listed: Complexio tells you which. Then open the app's **Permissions** tab and select
   **Grant admin consent**. Uploading takes a Teams Administrator.
3. Install the app in the chats and teams to ingest, if it isn't already. Complexio tells you
   whether the existing installations need reinstalling after a new version.

If you are moving from registrations you made yourself, Complexio ingests through the old ones
until it has switched over. After you delete them, remove the old registration's **Azure Event
Hubs Data Receiver** assignment from the namespace's **Access control (IAM)**: it then shows as
"Identity not found".

## Access groups

By default, the recipe creates these security groups and assigns them to Complexio - SSO:

| Group | Grants, once mapped in Settings |
| --- | --- |
| `complexio-owners` | Full configuration rights in Settings. Keep membership to a few administrators. |
| `complexio-ea` | Enterprise Automator, without email visibility. |
| `complexio-ea-evidence-view-full` | Enterprise Automator, with full email visibility. |
| `complexio-vendor-system-configuration` | Settings, for named Complexio staff. Needed for initial setup; optional afterwards. |
| `complexio-vendor-support` | Stevie and Enterprise Automator, for named Complexio staff, limited to the monitoring data set. |
| `complexio-stevie-<department>` | Stevie, one for each entry in `stevie_departments`. |

`access_group_name_prefix` replaces `complexio` in these names, to follow your own naming
convention.

You manage who is in each group. Add users directly: nested groups don't grant access. Share
`terraform output group_object_ids` with Complexio, since Settings refers to the groups by object
ID. If a group with one of these names already exists, for example a `complexio-owners` you
created by hand, the apply stops rather than creating a second one. Choose another
`access_group_name_prefix`, or set `create_and_assign_access_groups = false` and assign your
existing groups yourself.

To use only your own security groups, set `create_and_assign_access_groups = false` and assign
them to the Complexio - SSO enterprise application.

## What you manage in the Entra admin center

Later applies leave these as you set them:

- owners and notes of both registrations
- visibility to users, and whether sign-in is enabled
- which further users and groups are assigned to Complexio - SSO
- API permissions you add to Complexio - SSO for APIs other than Microsoft Graph, Complexio -
  Backend and itself
- who is in the access groups and in the **Complexio mailboxes** unit

Everything else, including permissions, redirect URIs and token settings, is put back as the
recipe defines it the next time it is applied.

## Credentials

- **Client secrets** are valid for `secret_validity_in_days` (365 by default). The certificates
  are valid for `certificate_validity_in_months` (12 by default). None renews itself.
  `terraform output credential_expiry` shows the dates.
- **Key Vault emails its certificate contacts** 30 days before a certificate expires. It has
  none until you add one, so add the address that should hear about it:
  ```bash
  az keyvault certificate contact add --vault-name <vault> --email <address>
  ```
  Contacts belong to the vault and cover every certificate in it.
- **To renew the secrets**, apply with
  `-replace=time_offset.secret_expiry`.
- **To renew a certificate**, create a new version of it in Key Vault with its own policy, then
  apply. The apply registers the new version on its registration in place of the old one.
  ```bash
  cert=<key_vault_secret_prefix>--CPX-BACKEND-CERTIFICATE   # or ...-SSO-CERTIFICATE
  az keyvault certificate show --vault-name <vault> --name "$cert" --query policy > policy.json
  az keyvault certificate create --vault-name <vault> --name "$cert" --policy @policy.json
  terraform apply
  ```
  Don't renew it with `-replace`: on a vault with purge protection, the deleted certificate
  can't be purged, and Terraform recovers it, old key included.
- **Either way**, agree a time with Complexio, because its services keep using the old credential
  until they next read the vault.
- **The Terraform state holds the client secrets.** Keep it somewhere only your administrators
  can read, such as an Azure Storage backend with access restricted to them.

## Environments

One pair of registrations serves all your Complexio environments, staging included, so apply
the recipe once for your tenant.
