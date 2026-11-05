# Seeds a cluster with Flux and ExternalSecrets, then hands it over to Flux.
#
# Everything runs through AKS run command (`az aks command invoke`, in scripts/run-command.sh): the
# API server is usually private, and run command reaches it through ARM.

locals {
  chart_versions = {
    flux             = "2.19.1"
    external_secrets = "2.14.0"
  }

  seed_manifest = templatefile("${path.module}/manifests/seed.yaml.tftpl", {
    external_key_vault_external_secrets_client_id = var.external_key_vault.external_secrets_client_id
    external_key_vault_tenant_id                  = var.external_key_vault.tenant_id
    external_key_vault_url                        = var.external_key_vault.key_vault_url
    customer_key_vault_external_secrets_client_id = var.customer_key_vault.external_secrets_client_id
    customer_key_vault_tenant_id                  = var.customer_key_vault.tenant_id
    customer_key_vault_url                        = var.customer_key_vault.key_vault_url
    acr_login_server                              = regex("^oci://([^/]+)/", var.oci_source_artifact.url)[0]
    oci_source_url                                = var.oci_source_artifact.url
    oci_source_ref                                = { for key, value in var.oci_source_artifact.ref : key => value if value != null }
    oci_source_path                               = var.oci_source_artifact.path
  })


  bootstrap_script = templatefile("${path.module}/scripts/bootstrap.sh.tftpl", {
    flux_chart_version             = local.chart_versions.flux
    external_secrets_chart_version = local.chart_versions.external_secrets
  })

  run_command_environment = {
    SUBSCRIPTION_ID = var.cluster.subscription_id
    RESOURCE_GROUP  = var.cluster.resource_group_name
    CLUSTER_NAME    = var.cluster.name
  }
}

# Once per cluster: changes to the script or the seed objects must not touch a cluster that Flux
# already manages.
resource "terraform_data" "bootstrap" {
  triggers_replace = [var.cluster.id]

  # Only orders the bootstrap after the grants it needs.
  input = var.cluster_access_granted

  provisioner "local-exec" {
    interpreter = ["bash"]
    command     = "${path.module}/scripts/run-command.sh"
    environment = merge(local.run_command_environment, {
      SCRIPT   = local.bootstrap_script
      MANIFEST = local.seed_manifest
    })
  }
}
