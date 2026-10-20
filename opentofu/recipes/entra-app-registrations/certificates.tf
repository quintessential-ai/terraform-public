# One certificate for each registration, generated in your Key Vault. Complexio's services read the
# key and certificate from the vault, as one PEM, to sign in with it. Key Vault emails its
# certificate contacts, if it has any, 30 days before one expires, and doesn't renew it: a renewed
# certificate has a new key, which the registration accepts only once it is registered. To renew
# one, create a new version in Key Vault and apply; the apply registers the new version.
resource "azurerm_key_vault_certificate" "this" {
  for_each = tomap(var.display_names)

  name         = "${local.key_vault_entry_prefix}-${upper(each.key)}-CERTIFICATE"
  key_vault_id = var.key_vault_id
  tags         = var.tags

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_type   = "RSA"
      key_size   = 2048
      reuse_key  = false
    }

    secret_properties {
      content_type = "application/x-pem-file"
    }

    lifetime_action {
      action {
        action_type = "EmailContacts"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    x509_certificate_properties {
      subject            = "CN=${each.value}"
      validity_in_months = var.certificate_validity_in_months
      key_usage          = ["digitalSignature"]
    }
  }
}

# Each certificate's public part, registered on its registration. The private key isn't sent to
# Microsoft Entra.
resource "azuread_application_certificate" "this" {
  for_each = azurerm_key_vault_certificate.this

  application_id = { sso = azuread_application.sso.id, backend = azuread_application.backend.id }[each.key]
  type           = "AsymmetricX509Cert"
  encoding       = "hex"
  value          = each.value.certificate_data
  start_date     = each.value.certificate_attribute[0].not_before
  end_date       = each.value.certificate_attribute[0].expires
}
