# Complexio Terraform modules and recipes

## What does this repo contain?

It contains Terraform code that provisions the cloud infrastructure Complexio needs to run.

The same code is published in two flavors: one for Terraform and one for OpenTofu. We recommend the Terraform flavor; use OpenTofu only if your organization doesn't support Terraform.

## How can I use it?

You can consume our code through Terragrunt (recommended) or as a module in your own Terraform code. In either case, you need the following:

- A blob container in a Storage Account where Terragrunt/Terraform can store the state file. See [azurerm remote backend](https://developer.hashicorp.com/terraform/language/backend/azurerm).
- `Storage Blob Data Contributor` on the Storage Account where the state is stored.
- Membership in one of the groups in `key_vault_secrets_officer_groups` (or `azure_rbac.cluster_admin_principal_ids`), since Terraform reads and writes secrets in the Key Vault it creates.
- `Owner` role when applying the `complexio-cluster` recipe.
- `Directory Administrator` role when applying the `entra-app-registrations` recipe.
- Terraform 1.16.0 or later, or OpenTofu 1.12.0 or later.

### Consuming it via Terragrunt (golden path)

A "recipe" is a root module that includes its own provider configuration. [Terragrunt](https://terragrunt.com/), a tool that orchestrates and runs Terraform code, is the simplest way to run one. To install it:

```sh
curl -sSfL --proto '=https' --tlsv1.2 https://terragrunt.com/install | bash
# Use ~/.zshrc instead if your shell is zsh, the default on macOS.
echo 'export PATH="$HOME/.terragrunt/bin:$PATH"' >> ~/.bashrc
```

On macOS, `brew install terragrunt` works too.

Create one directory per recipe, each with a `terragrunt.hcl`, and a `root.hcl` above them with what they share:

```
complexio/
├── root.hcl
├── complexio-cluster/
│   └── terragrunt.hcl
└── entra-app-registrations/
    └── terragrunt.hcl
```

<details>
<summary>complexio/root.hcl</summary>

```hcl
# complexio/root.hcl

terraform_binary = "terraform"

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
        key                  = "${path_relative_to_include()}/terraform.tfstate"
        use_azuread_auth     = true
    }
}
```

</details>

Each `terragrunt.hcl` points at one recipe and sets its inputs. The recipe already configures its providers.

<details>
<summary>complexio/complexio-cluster/terragrunt.hcl</summary>

```hcl
# complexio/complexio-cluster/terragrunt.hcl

include "root" {
    path = find_in_parent_folders("root.hcl")
}

terraform {
    source = "git::git@github.com:quintessential-ai/terraform-public.git//terraform/recipes/complexio-cluster"
}

inputs = {
    # Required
    #
    subscription_id                  = "<subscription-id>"
    resource_group_name              = "<resource-group-name>"
    region                           = "<region>"
    # The groups that get the "Key Vault Secrets Officer" and "Key Vault Certificates Officer" roles
    # in the Key Vault. Whoever runs Terraform, for this recipe or entra-app-registrations, needs to
    # be in one of these groups, since both write secrets in Key Vault. Only optional when they are
    # in azure_rbac.cluster_admin_principal_ids instead.
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

</details>

`entra-app-registrations` writes its credentials to the Key Vault that `complexio-cluster` creates, so it reads the vault from that recipe's outputs. Its [README](recipes/entra-app-registrations/README.public.md#inputs) describes every input.

<details>
<summary>complexio/entra-app-registrations/terragrunt.hcl</summary>

```hcl
# complexio/entra-app-registrations/terragrunt.hcl

include "root" {
    path = find_in_parent_folders("root.hcl")
}

terraform {
    source = "git::git@github.com:quintessential-ai/terraform-public.git//terraform/recipes/entra-app-registrations"
}

dependency "complexio_cluster" {
    config_path = "../complexio-cluster"

    # Lets `terragrunt validate` run before complexio-cluster is applied. `plan` and `apply` need
    # its real outputs.
    mock_outputs = {
        tenant_id       = "00000000-0000-0000-0000-000000000000"
        subscription_id = "00000000-0000-0000-0000-000000000000"
        key_vault_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
    }
    mock_outputs_allowed_terraform_commands = ["validate"]
}

inputs = {
    # Required
    #
    tenant_id       = dependency.complexio_cluster.outputs.tenant_id
    subscription_id = dependency.complexio_cluster.outputs.subscription_id
    key_vault_id    = dependency.complexio_cluster.outputs.key_vault_id
    # Host names your users open Complexio on. Complexio confirms them with you.
    browser_hosts   = ["<host-name>", ...]

    # Optional
    #
    # What Complexio may do in your Microsoft 365 tenant. Switch on only what you have agreed with
    # Complexio.
    features = {
        email_ingestion = true
        [...]
    }
    [...]
}
```

</details>

To run them, apply `complexio-cluster` first, since `entra-app-registrations` reads its outputs.

```sh
cd complexio/complexio-cluster
terragrunt plan
terragrunt apply

cd ../entra-app-registrations
terragrunt plan
terragrunt apply
```

### Consuming it as a module

> [!IMPORTANT]
> Consuming the recipes as modules isn't supported yet: the `modules-public` directory used below isn't published. Use [Terragrunt](#consuming-it-via-terragrunt-golden-path) until it is.

If you don't want to use Terragrunt, or you already have an existing Terraform codebase and want to embed our modules in your own modules or recipes, call the modules directly:

<details>
<summary>Example of how to consume our recipes as modules</summary>

```hcl
module "complexio_cluster" {
    source = "git::git@github.com:quintessential-ai/terraform-public.git//terraform/modules-public/complexio-cluster"
    providers = {
        azurerm                   = azurerm
        azurerm.parent_dns        = azurerm.parent_dns
        azurerm.network_appliance = azurerm.network_appliance
        azapi                     = azapi
    }

    # Input parameters
    #
    # The same as the inputs of complexio-cluster in the Terragrunt example, but without the
    # `subscription_id`. The subscription is already embedded into the providers that you define below.
}

module "complexio_entra_app_registrations" {
    source = "git::git@github.com:quintessential-ai/terraform-public.git//terraform/modules-public/entra-app-registrations"
    providers = {
        azuread = azuread
        azurerm = azurerm
    }

    key_vault_id = module.complexio_cluster.key_vault_id

    # Input parameters
    #
    # The other inputs of entra-app-registrations in the Terragrunt example, but without the
    # `tenant_id` and `subscription_id`. They are already embedded into the providers that you
    # define below.
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

# + provider definitions: the module needs three azurerm providers and one azapi provider. The
# default azurerm and the azapi providers point at the cluster's subscription; the "parent_dns"
# points at the subscription of the parent DNS zone, and the "network_appliance" at the subscription of
# your network appliance's VNet (with use_existing_network_appliance). Both can be the cluster's subscription.

# + provider definitions: complexio-cluster needs two azurerm providers and one azapi provider. The
# default azurerm and the azapi providers point at the cluster's subscription; the "parent_dns"
# points at the subscription of the parent DNS zone and the "network_appliance" at the subscription of
# your network appliance's VNet (with use_existing_network_appliance). Both can point to the same subscription as
# the cluster's.
# entra-app-registrations needs an azuread provider for your tenant, and the default azurerm
# provider, since the Key Vault is in the cluster's subscription.
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
#
# provider "azurerm" {
#     alias           = "network_appliance"
#     subscription_id = "<network-appliance-vnet-subscription-id>"
#     features {}
# }
#
# provider "azuread" {
#     tenant_id = "<tenant-id>"
# }

# + variable definition, if you don't want to hardcode values in the input parameters.
```

</details>

Note that this example uses `terraform/modules-public/<name>` instead of `terraform/recipes/<name>`. The code is almost the same in both, except that `modules-public` has no `provider` blocks, so it can be used as a regular module.

Both modules in one root module share one state, and whoever applies it needs the access of both recipes. To keep them apart, as the Terragrunt layout does, call each module from its own root module and pass the Key Vault ID from one to the other.

## What to avoid

- Never consume the modules in `modules-internal`. The only public-facing code is the `recipes` and `modules-public`.
- Make every change by upgrading to a new version of the recipe or module. Don't edit the code locally or change resources in the Azure portal: the drift can break existing infrastructure and make future upgrades fail.
- The Terraform state cannot be kept locally. It must be stored in a remote backend.

## Which kind of infrastructure does it provision?

### `recipes/complexio-cluster`

- VNet, subnets and (optional) VNet peering.
- AKS cluster with Karpenter and OIDC + Workload Identity enabled. The API server is private by default (API Server VNet Integration): it has no public endpoint.
- Private Azure Database for PostgreSQL flexible server in the cluster's VNet.
- Azure Key Vault, where Complexio's credentials are stored. The `key_vault_id` and `key_vault_name` outputs give it.
- Azure Storage account for Complexio's object storage, reachable only through a private endpoint in the cluster's VNet (on by default).
- Workload identities for ExternalSecrets, ExternalDNS, CertManager, InferenceWorker and S3Proxy.
- A static public IP for the gateway's LoadBalancer Service (on by default).
- A NAT gateway with a static public IP for the cluster's egress (`egress_public_ip_address` output), unless traffic goes through the customer's existing network appliance.
- (Optional) Traffic in and out through the customer's existing network appliance, such as a firewall (`use_existing_network_appliance`). Its [README](recipes/complexio-cluster/README.public.md) lists what to set up on it before apply.
- (Optional) Azure Bastion (`create_bastion`) to reach the private API server.
- (Optional) Child DNS zone (`dns_zone`).

### `recipes/entra-app-registrations`

Applied by a directory administrator rather than a subscription owner. Its [README](recipes/entra-app-registrations/README.public.md) has the roles it needs, every switch, and the steps after apply.

- The Complexio - SSO and Complexio - Backend app registrations and enterprise applications in your Microsoft Entra tenant, with admin consent for the Microsoft Graph permissions of the features you switch on (`features`).
- Their certificates, client secrets and IDs, written to the Key Vault that `complexio-cluster` creates.
- Complexio's standard access groups, assigned to Complexio - SSO (on by default; `create_and_assign_access_groups`).
- The Complexio mailboxes administrative unit, and, with email features, the Exchange Online PowerShell that limits Complexio's mailbox access to its members.
