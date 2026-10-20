# Complexio Terraform modules and recipes

## What does this repo contain?

It contains Terraform code that provisions the cloud infrastructure Complexio needs to run.

The same code is published in two flavors: one for Terraform and one for OpenTofu. We recommend the Terraform flavor; use OpenTofu only if your organization doesn't support Terraform.

## How can I use it?

You can consume our code through Terragrunt (recommended) or as a module in your own Terraform code. In either case, you need the following:

- `Owner` (or `Contributor` plus `Role Based Access Control Administrator`) access in the target Azure subscription, since it creates managed identities and role assignments. See the [last section](#which-kind-of-infrastructure-does-it-provision).
- A blob container in a Storage Account where Terragrunt/Terraform can store the state file. See [azurerm remote backend](https://developer.hashicorp.com/terraform/language/backend/azurerm).
- `Storage Blob Data Contributor` on the Storage Account where the state is stored.
- Membership in one of the groups in `key_vault_secrets_officer_groups` (or `azure_rbac.cluster_admin_principal_ids`), since Terraform reads and writes secrets in the Key Vault it creates. If you were just added to the group, sign in again (`az login`) so your token includes it; until then, Terraform fails with a 403 on the Key Vault.
- Terraform 1.16.0 or later, or OpenTofu 1.12.0 or later.
- The Azure CLI (`az`), signed in, on the machine that runs Terraform.

### Consuming it via Terragrunt (golden path)

A "recipe" is a root module that includes its own provider configuration. [Terragrunt](https://terragrunt.com/), a tool that orchestrates and runs Terraform code, is the simplest way to run one. To install it:

```sh
curl -sSfL --proto '=https' --tlsv1.2 https://terragrunt.com/install | bash
# Use ~/.zshrc instead if your shell is zsh, the default on macOS.
echo 'export PATH="$HOME/.terragrunt/bin:$PATH"' >> ~/.bashrc
```

On macOS, `brew install terragrunt` works too.

Because the recipe already configures the providers, you only need to define the remote state backend and the recipe's inputs.

```hcl
# <some-dir>/terragrunt.hcl

terraform_binary = "terraform"

terraform {
    source = "git::git@github.com:quintessential-ai/terraform-public.git//terraform/recipes/complexio-cluster"
}

# Example of remote state stored in Azure Blob Storage
remote_state {
    backend = "azurerm"
    generate = {
        path      = "backend.tf"
        if_exists = "overwrite_terragrunt"
    }
    config = {
        storage_account_name = "<storage-account>"
        container_name       = "<container-name>"
        key                  = "${get_path_from_repo_root()}.tfstate"
        use_azuread_auth     = true
    }
}

inputs = {
    # Required
    #
    subscription_id                  = "<subscription-id>"
    resource_group_name              = "<resource-group-name>"
    region                           = "<region>"
    # The groups that get the "Key Vault Secrets Officer" role in the Key Vault. Whoever runs
    # Terraform needs to be in one of these groups, since the Terraform code writes some secrets in
    # Key Vault. Only optional when they are in azure_rbac.cluster_admin_principal_ids instead.
    key_vault_secrets_officer_groups = ["<group-id>", ...]

    # Optional, but highly recommended
    #
    # Creates the child zone "<prefix>.<parent-zone-name>", e.g. "acme.example.com".
    dns_zone = {
        prefix           = "<prefix>"
        parent_zone_name = "<parent-zone-name>"
    }
    [...]
}
```

To run it:

```sh
cd <some-dir>
terragrunt plan
terragrunt apply
```

### Consuming it as a module

If you don't want to use Terragrunt, or you already have an existing Terraform codebase and want to embed our modules in your own modules or recipes, call the module directly:

```hcl
module "complexio_infra" {
    source = "git::git@github.com:quintessential-ai/terraform-public.git//terraform/modules-public/complexio-cluster"
    providers = {
        azurerm            = azurerm
        azurerm.parent_dns = azurerm.parent_dns
        azapi              = azapi
    }

    # Input parameters
    #
    # The same as the input parameters for the Terragrunt example, but without the `subscription_id`.
    # The subscription is already embedded into the providers that you define below.
}

# Example of remote state stored in Azure Blob Storage
terraform {
    backend "azurerm" {
        storage_account_name = "<storage-account>"
        container_name       = "<container-name>"
        key                  = "<state-name>.tfstate"
        use_azuread_auth     = true
    }
}

# + provider definitions: the module needs two azurerm providers and one azapi provider. The default
# azurerm and the azapi providers point at the cluster's subscription; the "parent_dns" points at
# the subscription of the parent DNS zone, which can be the same subscription.
#
# provider "azurerm" {
#     subscription_id = "<subscription-id>"
#     features {
#         postgresql_flexible_server {
#             restart_server_on_configuration_value_change = false
#         }
#     }
# }
#
# provider "azapi" {
#     subscription_id = "<subscription-id>"
# }
#
# provider "azurerm" {
#     alias           = "parent_dns"
#     subscription_id = "<parent-dns-zone-subscription-id>"
#     features {}
# }

# + variable definition, if you don't want to hardcode values in the input parameters for "complexio_infra".
```

Note that this example uses `terraform/modules-public/complexio-cluster` instead of `terraform/recipes/complexio-cluster`. The code is almost the same in both, except that `modules-public` has no `provider` blocks, so it can be used as a regular module.

## What to avoid

- Never consume the modules in `modules-internal`. The only public-facing code is the `recipes` and `modules-public`.
- Make every change by upgrading to a new version of the recipe or module. Don't edit the code locally or change resources in the Azure portal: the drift can break existing infrastructure and make future upgrades fail.
- The Terraform state cannot be kept locally. It must be stored in a remote backend.

## Which kind of infrastructure does it provision?

### `recipes/complexio-cluster`

- VNet, subnets and (optional) VNet peering.
- AKS cluster with Karpenter and OIDC + Workload Identity enabled. The API server is private by default (API Server VNet Integration): it has no public endpoint.
- Private Azure Database for PostgreSQL flexible server in the cluster's VNet.
- Azure Key Vault.
- Workload identities for ExternalSecrets, ExternalDNS, CertManager and InferenceWorker.
- A static public IP for the gateway's LoadBalancer Service (on by default).
- (Optional) Azure Bastion (`create_bastion`) to reach the private API server.
- (Optional) Child DNS zone (`dns_zone`).

### `recipes/entra-app-registrations`

Applied by a directory administrator rather than a subscription owner. Its [README](recipes/entra-app-registrations/README.public.md) has the roles it needs, every switch, and the steps after apply.

- The Complexio - SSO and Complexio - Backend app registrations and enterprise applications in your Microsoft Entra tenant, with admin consent for the Microsoft Graph permissions of the features you switch on (`features`).
- Their certificates, client secrets and IDs, written to your Key Vault.
- (Optional) Complexio's standard access groups, assigned to Complexio - SSO (`create_and_assign_access_groups`).
- The Complexio mailboxes administrative unit, and, with email features, the Exchange Online PowerShell that limits Complexio's mailbox access to its members.
