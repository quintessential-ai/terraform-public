# The Exchange Online roles that email ingestion and Enterprise Automator email need.
locals {
  exchange_mail_roles = concat(
    var.features.email_ingestion ? ["Application Mail.Read"] : [],
    var.features.automator_email ? ["Application Mail.ReadWrite", "Application Mail.Send"] : [],
  )
}

# The mailboxes Complexio may reach. Microsoft Entra can only grant mailbox access for every
# mailbox in the tenant, so it is granted in Exchange Online instead, limited to the members of
# this administrative unit: see the exchange_mailbox_access_commands output. Add the users
# themselves; a group added to the unit doesn't bring its members in. Later applies leave its
# members as you set them. It exists whether or not a mail feature is on, so switching the
# features off and on again keeps the unit the Exchange grants point at.
resource "azuread_administrative_unit" "mailboxes" {
  display_name = "Complexio mailboxes"
  description  = "Users whose mailboxes Complexio may reach."

  lifecycle {
    ignore_changes = [members]
  }
}
