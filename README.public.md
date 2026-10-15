# Complexio Terraform modules and recipes

## What does this repo contain?

It contains Terraform code that provisions the cloud infrastructure Complexio needs to run.

The same code is published in two flavors: one for Terraform and one for OpenTofu. We recommend the Terraform flavor; use OpenTofu only if your organization doesn't support Terraform.

## How can I use it?

You can consume our code through Terragrunt (recommended) or as a module in your own Terraform code. In either case, you need the following:

- `Owner` (or `Contributor` plus `Role Based Access Control Administrator`) access in the target Azure subscription, since it creates managed identities and role assignments. See the [last section](#which-kind-of-infrastructure-does-it-provision).
- A blob container in a Storage Account where Terragrunt/Terraform can store the state file. See [azurerm remote backend](https://developer.hashicorp.com/terraform/language/backend/azurerm).
- `Storage Blob Data Contributor` on the Storage Account where the state is stored.

### Consuming it via Terragrunt (golden path)

A "recipe" is a root module that includes its own provider configuration. [Terragrunt](https://terragrunt.com/), a tool that orchestrates and runs Terraform code, is the simplest way to run one.

Because the recipe already configures the providers, you only need to define the remote state backend and the recipe's inputs.

```hcl
# <some-dir>/terragrunt.hcl

terraform_binary = "terraform"

terraform {
    source = "git::git@github.com:quintessential-ai/terraform-public.git//terraform/recipes/managed-aks"
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
    subscription_id     = "<subscription_id>"
    resource_group_name = "<resource-group-name>"
    default_location    = "westeurope"
    kubernetes_version  = "1.36"
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
    source = "git::git@github.com:quintessential-ai/terraform-public.git//terraform/modules-public/managed-aks"
    providers = {
        azurerm            = azurerm
        azurerm.parent_dns = azurerm.parent_dns
    }

    # Input parameters
    resource_group_name = "<resource-group-name>"
    default_location    = "<location>"
    kubernetes_version  = "<k8s-version>"
    [...]
}

# + backend configuration.

# + variable definition, if you don't want to hardcode values in the input parameters for "complexio_infra".

# + provider definitions: the module needs two azurerm providers. The default one points at the
# cluster's subscription; the one aliased "parent_dns" points at the subscription of the parent
# DNS zone, which can be the same subscription.
#
# provider "azurerm" {
#     subscription_id = "<subscription_id>"
#     features {}
# }
#
# provider "azurerm" {
#     alias           = "parent_dns"
#     subscription_id = "<parent-dns-zone-subscription_id>"
#     features {}
# }
```

Note that this example uses `terraform/modules-public/managed-aks` instead of `terraform/recipes/managed-aks`. The code is almost the same in both, except that `modules-public` has no `provider` blocks, so it can be used as a regular module.

## What to avoid

- Never consume the modules in `modules-internal`. The only public-facing code is the `recipes` and `modules-public`.
- Make every change by upgrading to a new version of the recipe or module. Don't edit the code locally or change resources in the Azure portal: the drift can break existing infrastructure and make future upgrades fail.
- The Terraform state cannot be kept locally. It must be stored in a remote backend.

## Which kind of infrastructure does it provision?

### `recipes/managed-aks`

- VNet, subnets and potential VNet peering.
- AKS cluster with Karpenter and OIDC + Workload Identity enabled. The API server is private by default (API Server VNet Integration): it has no public endpoint.
- Workload identities for ExternalSecrets, ExternalDNS, CertManager and InferenceWorker.
- A static public IP for the gateway's LoadBalancer Service (on by default).
- (Optional) Azure Bastion (`create_bastion`) to reach the private API server.
- (Optional) Azure Key Vault (`create_azure_key_vault`).
- (Optional) Child DNS zone (`dns_zone`).
- (Optional) Private Azure Database for PostgreSQL flexible server in the cluster's VNet (`postgres`).
