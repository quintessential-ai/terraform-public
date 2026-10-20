# entra-app-registrations

Creates the Microsoft Entra app registrations Complexio runs with in your tenant, grants the
Microsoft Graph permissions for the features you choose, and writes their credentials to your
Key Vault. Your directory administrator applies it; Complexio never needs write access to your
directory.

## What gets created

| In Microsoft Entra | What it is for |
| --- | --- |
| **Complexio - SSO** app registration and enterprise application | Sign-in to Stevie, Settings and Enterprise Automator. Only the users and groups assigned to the enterprise application can sign in, and tokens carry only those groups. |
| **Complexio - Backend** app registration and enterprise application | What Complexio's services use to reach Microsoft 365, with the permissions of the features you switch on. |
| Admin consent for both | So users aren't asked to consent when they first sign in. |
| **Complexio mailboxes** administrative unit | The mailboxes Complexio may reach. See [Mailbox access](#mailbox-access). |
| Access groups (when `create_and_assign_access_groups` is on) | Security groups, assigned to Complexio - SSO. See [Access groups](#access-groups). |

| In your Key Vault, under `<key_vault_secret_prefix>--` | Holds |
| --- | --- |
| `CPX-TENANT-ID` | Your tenant ID |
| `CPX-SSO-CLIENT-ID` | Complexio - SSO's client ID |
| `CPX-SSO-CHAT-API-SECRET`, `CPX-SSO-GATEWAY-SECRET` | Complexio - SSO's two client secrets, until Stevie signs in with the certificate |
| `CPX-SSO-CERTIFICATE` | Complexio - SSO's certificate and private key |
| `CPX-BACKEND-CLIENT-ID` | Complexio - Backend's client ID |
| `CPX-BACKEND-SECRET` | Complexio - Backend's client secret |
| `CPX-BACKEND-CERTIFICATE` | Complexio - Backend's certificate and private key |

Each certificate is generated in the vault. Only its public part is registered in Microsoft
Entra; Complexio's services read the key from here.

Nothing leaves your tenant. Complexio's services read these entries from the vault.

## Before you start

- **Roles.** Apply as a **Global Administrator** for now; a narrower set of roles is being
  confirmed. On the Key Vault you also need **Key Vault Certificates Officer** and
  **Key Vault Secrets Officer**. The [Mailbox access](#mailbox-access) step needs an
  **Exchange Administrator**.
- **A Key Vault** with Azure RBAC authorization, in a subscription you can reach. If the vault
  has a firewall, allow the machine you run Terraform from.
- **The host names** your users open Complexio on. Complexio confirms them with you.
- **Terraform 1.11.4 or later**, or OpenTofu, and the Azure CLI signed in to your tenant
  (`az login --tenant <tenant_id>`).
- **A remote backend for the state**, as for every recipe. See
  [How can I use it?](../../README.public.md#how-can-i-use-it).

## Inputs

Run the recipe like the others, from `//terraform/recipes/entra-app-registrations`, through
Terragrunt or Terraform (see [How can I use it?](../../README.public.md#how-can-i-use-it)). The
inputs it needs are:

```hcl
tenant_id       = "<tenant_id>"
subscription_id = "<subscription_id of the Key Vault>"
key_vault_id    = "/subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.KeyVault/vaults/<key_vault_name>"
browser_hosts   = ["complexio.example.com"]
```

<details>
<summary>A fuller example</summary>

```hcl
tenant_id       = "<tenant_id>"
subscription_id = "<subscription_id of the Key Vault>"
key_vault_id    = "/subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.KeyVault/vaults/<key_vault_name>"

# Host names your users open Complexio on. Complexio confirms them with you.
browser_hosts = ["complexio.example.com"]
# MCP server host names, if you use them.
mcp_hosts = []

# What Complexio may do in your Microsoft 365 tenant. Switch on only what you have agreed with
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
  stevie_mail_delegated       = false
  stevie_calendar_delegated   = false
  stevie_onedrive_delegated   = false
  stevie_people_delegated     = false
  stevie_meetings_delegated   = false
  stevie_teams_delegated      = false
  stevie_sharepoint_delegated = false

  # Let Stevie write mail drafts, and send the ones the user approves, as the user.
  stevie_mail_drafting_delegated = false
  stevie_mail_sending_delegated  = false # Needs stevie_mail_drafting_delegated.
}

# Create Complexio's standard access groups and assign them to Complexio - SSO.
create_and_assign_access_groups = false
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

The plan lists every permission it grants. `terraform output application_permissions`,
`sso_delegated_permissions` and `backend_delegated_permissions` show them again after apply.

## Features

Each switch in `features` grants the Microsoft Graph permissions one feature needs, and nothing
is granted for a switch that is off. Switch on only what you have agreed with Complexio.

| Switch | Default | What it lets Complexio do |
| --- | --- | --- |
| `email_ingestion` | on | Ingest the mailboxes you choose. Needs the [Mailbox access](#mailbox-access) step. |
| `teams_ingestion_where_installed` | off | Ingest only the chats and teams you install the Complexio Assistant Teams app in. Nothing else is reachable. |
| `teams_ingestion_tenant_wide` | off | Ingest the channels you install the Complexio Assistant Teams app in, with tenant-wide permissions instead of the app's own. Microsoft Graph then lets Complexio read every team's channels. Chats aren't included. Switch it on only if Complexio asks you to. |
| `settings_directory` | on | List users, departments and security groups in Settings. |
| `automator_email` | off | Let Enterprise Automator draft and send mail from the mailboxes you choose. Needs the [Mailbox access](#mailbox-access) step. |
| `usage_metrics` | on | Report usage by department. |
| `stevie_mail_delegated` | off | Let Stevie read and send the signed-in user's mail. |
| `stevie_calendar_delegated` | off | Let Stevie read the signed-in user's calendar and check attendees' availability. |
| `stevie_onedrive_delegated` | off | Let Stevie browse and read the signed-in user's OneDrive. |
| `stevie_people_delegated` | off | Let Stevie search people in your organization. |
| `stevie_meetings_delegated` | off | Let Stevie find meetings and read their transcripts. |
| `stevie_teams_delegated` | off | Let Stevie read the signed-in user's teams, channels and chats. |
| `stevie_sharepoint_delegated` | off | Let Stevie search and read the SharePoint sites, lists and files the signed-in user can open. |
| `stevie_mail_drafting_delegated` | off | Let Stevie write reply and forward drafts in the signed-in user's mailbox. |
| `stevie_mail_sending_delegated` | off | Let Stevie send the drafts the signed-in user approves. Needs `stevie_mail_drafting_delegated`. |

Switches ending in `_delegated` act as the signed-in user, so they never reach further than what
that user can already see. They are granted to Complexio - SSO, except mail drafting and sending,
which are granted to Complexio - Backend. The others work without a signed-in user.
[`permissions.tf`](permissions.tf) lists each permission with what it is needed for.

`additional_application_permissions` adds further application permissions by name, if Complexio
asks for them. It refuses mailbox, calendar and contact permissions, which would reach every
mailbox in your tenant.

## Mailbox access

Microsoft Entra can only grant mailbox access for every mailbox in your tenant. Exchange Online
can grant it for chosen mailboxes only, so that is where `email_ingestion` and `automator_email`
grant it. This recipe never grants mailbox access in Entra: if it did, the Exchange scope would
have no effect, because Exchange adds the two together.

> **Don't add mail permissions to Complexio - Backend in the Entra admin center.** Its API
> permissions show no mail permission, and that is intended: mailbox access is in Exchange.
> Adding `Mail.Read`, `Mail.ReadWrite` or `Mail.Send` as an application permission and granting
> admin consent would open every mailbox in your tenant. A later apply removes the permission
> from the list but not the consent, so revoke it yourself under the enterprise application's
> **Permissions** if it ever happens.

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

Complexio can't read, draft or send mail until this is done. Users you add to the unit later are
in scope without running the commands again. If Complexio - Backend is ever recreated, Exchange
removes its grants with it: run the commands again from the new output.

Microsoft documents this in
[Role Based Access Control for Applications in Exchange Online](https://learn.microsoft.com/en-us/exchange/permissions-exo/application-rbac).

## Access groups

With `create_and_assign_access_groups = true`, the recipe creates these security groups and
assigns them to Complexio - SSO:

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
`access_group_name_prefix`, or leave this off and assign your existing groups yourself.

You can also leave this off and assign your own security groups to the Complexio - SSO
enterprise application.

## What you manage in the Entra admin center

Later applies leave these as you set them:

- owners and notes of both registrations
- visibility to users, and whether sign-in is enabled
- which further users and groups are assigned to Complexio - SSO
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
