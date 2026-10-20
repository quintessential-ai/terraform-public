# What both registrations show in the Entra admin center and in My Apps. The note on Complexio -
# Backend is set once, when it is created; after that it is yours to change.
locals {
  logo = filebase64("${path.module}/complexio-logo.png")

  sso_description     = "Sign-in for Complexio: Stevie, Settings and Enterprise Automator."
  backend_description = "Lets Complexio's services reach Microsoft 365 on your organization's behalf."
  backend_notes       = "Mailbox access is granted in Exchange Online, limited to the members of the Complexio mailboxes administrative unit. Don't add mail permissions to this application: Exchange adds the two grants together, so every mailbox in the tenant would become reachable."
}
