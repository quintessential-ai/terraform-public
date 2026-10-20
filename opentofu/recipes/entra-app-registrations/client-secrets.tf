# When the client secrets expire, var.secret_validity_in_days after they are created. It stays
# fixed until you renew them.
resource "time_offset" "secret_expiry" {
  offset_days = var.secret_validity_in_days
}

# Complexio - SSO's client secret for Stevie Chat API, until it signs in with the certificate.
resource "azuread_application_password" "sso_chat_api" {
  application_id = azuread_application.sso.id
  display_name   = "Stevie Chat API"
  end_date       = time_offset.secret_expiry.rfc3339
}

# Complexio - SSO's client secret for Stevie Gateway, until it signs in with the certificate.
resource "azuread_application_password" "sso_gateway" {
  application_id = azuread_application.sso.id
  display_name   = "Stevie Gateway"
  end_date       = time_offset.secret_expiry.rfc3339
}

# Complexio - Backend's client secret, for the services that sign in with a secret.
resource "azuread_application_password" "backend" {
  application_id = azuread_application.backend.id
  display_name   = "Complexio services"
  end_date       = time_offset.secret_expiry.rfc3339
}
