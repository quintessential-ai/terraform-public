# Complexio infrastructure code for Azure

This repository holds the Terraform code that creates the Azure resources the Complexio AI System runs on. You run it in your own Azure subscription and Microsoft Entra tenant, and you can review every resource before it is created.

It has two recipes: `complexio-cluster` creates the AKS cluster, and `entra-app-registrations` creates Complexio's app registrations in your Entra tenant.

The same code is published for Terraform (`terraform/`) and for OpenTofu (`opentofu/`). Use the Terraform version unless your organization only allows OpenTofu.

## What the code creates

### The `complexio-cluster` recipe

A private AKS cluster, a private PostgreSQL flexible server, a private storage account, a Key Vault, one managed identity per service that calls Azure, and the virtual network the cluster runs in. All traffic in and out of the cluster goes through a network appliance: two small Linux VMs by default, an Azure Firewall, or your own firewall.

The recipe's last step installs Flux and External Secrets in the cluster. Flux downloads Complexio's application from `complexio.azurecr.io` and keeps it up to date. Complexio operates the application from then on.

### The `entra-app-registrations` recipe

- Two app registrations. **Complexio - SSO** signs your users in. **Complexio - Backend** is what Complexio's services use to reach Microsoft 365, with the permissions of the features you switch on.
- Their certificates and secrets, written to the Key Vault that `complexio-cluster` created.
- Complexio's standard access groups, such as `complexio-owners`.
- The **Complexio mailboxes** administrative unit, which limits the mailboxes Complexio can reach.

## Before the first run

### What to prepare

- The GPU quota listed in Complexio's IT Infrastructure Requirements needs to be available in the chosen region.
- 6 vCPUs of quota for the `standardBpsv2Family` VM family in the chosen region, for the network appliance's VMs. Not needed with an Azure Firewall or your own firewall.
- An Entra security group for the administrators. Its members are the user who runs Terraform and Complexio's engineers as guest users (Conditional Access policies must allow those guests to sign in).
- The person responsible for running the recipes needs the following roles assigned:
  - **Owner** on the subscription.
  - **Global Administrator** in your Entra tenant.
  - **Exchange Administrator**, for the mailbox step after the run.
  - **Network Contributor** on your firewall's virtual network, only with your own firewall.
- A container in an Azure storage account for the Terraform state, with **Storage Blob Data Contributor** for whoever runs Terraform.
- The two input values provided by Complexio: `customer_name` and `external_key_vault`.
- Tools: Terraform 1.16.0 (or OpenTofu 1.12.0), [Terragrunt](https://terragrunt.com/), git and the Azure CLI signed in to your tenant with `az login --tenant <tenant-id>`.

### What to decide

These are the essential decisions: they’re all you need to get the cluster up and running. To fine-tune the recipes further, “All available resources per recipe” at the end of this page lists every option they support. If you have any questions, contact Complexio.

#### For the `complexio-cluster` recipe

##### **Subscription, tenant and region**

Decide which Entra tenant and Azure subscription Complexio runs in, and choose an Azure region with availability zones where Microsoft has approved the GPU quota listed in Complexio’s IT Infrastructure Requirements. Everything is created in that one region.

Terraform inputs: `subscription_id`, `region`.

##### Who administers the cluster

Create one Entra security group for the administrators. Put whoever runs Terraform in it, and the named Complexio engineers, invited as guest users. The group gets administrator access to the cluster and the Key Vault.

Terraform input: `admin_groups`.

##### Network address range

Choose a /16 range for the cluster’s virtual network. The default is `10.224.0.0/16`. The recipe creates a separate virtual network with it, so Complexio stays apart from your other workloads and nothing has to be carved out of an existing network. The range must not overlap any network that will be connected to it.

Terraform input: `vnet_cidr`.

##### Internet traffic: the network appliance

All the cluster’s traffic to and from the internet goes through a network appliance, and the cluster itself has no public IP. Only the applications in the cluster are reachable from the internet. The AKS control plane stays private, and only the people you grant access to through Azure RBAC can reach it.

By default, the recipe creates the appliance: two small Linux VMs that Azure keeps patched. It can create an Azure Firewall instead. Either way, the `network_appliance_public_ip_address` output is where the cluster’s internet traffic comes from, and where your DNS records for Complexio point.

The recipe can also send the traffic through a firewall that belongs to you. Use this option only if your policy requires it. The firewall forwards HTTPS to the cluster’s private load balancer, and it must allow the cluster’s outbound traffic before the first run, or the cluster can’t start. The [complexio-cluster README](https://github.com/quintessential-ai/terraform-public/blob/main/terraform/recipes/complexio-cluster/README.public.md#traffic-through-the-customers-existing-network-appliance) lists the rules. Whoever runs Terraform needs Network Contributor on the firewall’s virtual network.

The appliance can be changed on an existing cluster, for example to your own firewall later. Terraform input: `network_appliance`, `"vm_scale_set"` (default) or `"azure_firewall"`. To use your own firewall, set:

- `network_appliance = "existing"`
- `existing_network_appliance_private_ip`: the firewall’s private IP.
- `existing_network_appliance_vnet_id`: the ID of the firewall’s virtual network.
- `existing_network_appliance_subscription_id`: the subscription of that virtual network, only if it’s not the cluster’s subscription.

##### DNS and certificates (optional)

The recipe can create an Azure DNS zone for a Complexio subdomain, for example `complexio.example.com`. The cluster then manages its DNS records and issues and renews its TLS certificates automatically, so no manual DNS changes are needed when Complexio adds a service. It can only write A, AAAA, CNAME and TXT records in that zone, and nothing in any other zone.

The parent zone has to delegate to the new zone with NS records, which your DNS administrator adds after the run. The name servers to use are in the `child_dns_zone_name_servers` output. Without a zone, you create each DNS record by hand and agree with Complexio how the TLS certificates are issued.

Terraform input: `dns_zone`.

##### Database size

By default, the database gets a 2 TB disk, the production size in Complexio’s IT Infrastructure Requirements. For a pilot, a 1 TB disk is enough: set `postgres_storage_size_mb = 1048576`. The disk can grow later but never shrink, so it’s better to start small and grow it when needed.

#### For the `entra-app-registrations` recipe

##### Host name

Choose the address your users will open Complexio on, for example `complexio.example.com`. It's required, because sign-in redirects back to this address only.

Terraform input: `browser_hosts`.

##### What Complexio may reach in Microsoft 365

Switch on what your statement of work covers and nothing else. By default, email ingestion, the Settings directory, usage metrics and the Stevie features are on. Teams ingestion and Enterprise Automator email are off. Each feature grants only the Microsoft Graph permissions it needs.

Also decide which mailboxes Complexio may read: access is limited in Exchange Online to the mailboxes you add to the Complexio mailboxes administrative unit. For Teams ingestion, choose an Event Hubs namespace in your subscription to receive the Teams notifications. You can use Complexio's standard access groups, which is the default, or your own.

Terraform inputs: `features`, `event_hub_namespace_id` for Teams ingestion, and `create_and_assign_access_groups` for the standard access groups.

## How to run it

[Terragrunt](https://terragrunt.com/) runs each recipe with your inputs and stores its state in your storage account. To install it:

```bash
curl -sSfL --proto '=https' --tlsv1.2 https://terragrunt.com/install | bash
# Use ~/.zshrc instead if your shell is zsh, the default on macOS.
echo 'export PATH="$HOME/.terragrunt/bin:$PATH"' >> ~/.bashrc
```

On macOS, `brew install terragrunt` works too.

Terragrunt runs Terraform, so Terraform must be installed too. On macOS:

```bash
brew install hashicorp/tap/terraform
```

Create one directory per recipe, each with a `terragrunt.hcl`, and a `root.hcl` above them that configures where both recipes store their Terraform state:

```
complexio/
├── root.hcl
├── complexio-cluster/
│   └── terragrunt.hcl
└── entra-app-registrations/
    └── terragrunt.hcl
```

```hcl
# complexio/root.hcl

terraform_binary = "terraform"

# The Terraform state, in your Azure storage account.
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

Each `terragrunt.hcl` points at one recipe and sets its inputs. Every input not shown keeps the default Complexio recommends. To stay on the version you reviewed, add `?ref=<commit>` to the end of `source`.

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
    customer_name                    = "<customer-name>"
    # Given by Complexio.
    external_key_vault = {
        external_secrets_client_id = "<client-id>"
        name                       = "<vault-name>"
    }
    # Whoever runs Terraform must be in one of these groups.
    admin_groups                     = ["<group-id>", ...]
    # A free /16.
    vnet_cidr                        = "<vnet-cidr>"

    # Optional, but highly recommended
    #
    # Creates the child zone "<prefix>.<parent-zone-name>", e.g. "acme.example.com".
    dns_zone = {
        prefix           = "<prefix>"
        parent_zone_name = "<parent-zone-name>"
    }

    # Only with your own firewall.
    # network_appliance                     = "existing"
    # existing_network_appliance_private_ip = "<firewall-private-ip>"
    # existing_network_appliance_vnet_id    = "<firewall-vnet-resource-id>"
    [...]
}
```

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
    # Read from the outputs of complexio-cluster.
    tenant_id       = dependency.complexio_cluster.outputs.tenant_id
    subscription_id = dependency.complexio_cluster.outputs.subscription_id
    key_vault_id    = dependency.complexio_cluster.outputs.key_vault_id

    # The host names your users open Complexio on, e.g. "complexio.example.com". Sign-in redirects
    # back to these hosts only. Complexio confirms them with you.
    browser_hosts = ["<host-name>"]

    # What Complexio may do in your Microsoft 365 tenant. Switch on only what you have agreed with
    # Complexio.
    features = {
        email_ingestion = true
        [...]
    }
}
```

The [entra-app-registrations README](https://github.com/quintessential-ai/terraform-public/blob/main/terraform/recipes/entra-app-registrations/README.public.md#features) lists every `features` switch and its default.

Run `complexio-cluster` first, because `entra-app-registrations` reads its outputs. `plan` shows what will be created without changing anything; `apply` shows the plan again and asks before it creates anything.

```bash
cd complexio/complexio-cluster
terragrunt plan
terragrunt apply

cd ../entra-app-registrations
terragrunt plan
terragrunt apply
```

After `entra-app-registrations`, follow its [steps after the run](https://github.com/quintessential-ai/terraform-public/blob/main/terraform/recipes/entra-app-registrations/README.public.md#mailbox-access) for mailbox access and, with Teams ingestion, the Teams app.

## Rules

- Never call the modules in `modules-internal` directly. Only the `recipes` are meant for you.
- Make every change through the inputs or a newer version of the recipe. Don't edit the code or change its resources in the Azure portal. Such changes can break the infrastructure and make later runs fail.
- Keep the Terraform state in a remote backend, never on a laptop.

## All available resources per recipe

This is the complete list of what the recipes support. Many items are optional and are only created when you switch them on. What the code creates, at the top of this page, describes a standard installation.

### `recipes/complexio-cluster`

- VNet, subnets and (optional) VNet peering.
- AKS cluster with Karpenter and OIDC + Workload Identity enabled. The API server is private by default (API Server VNet Integration): it has no public endpoint.
- Private Azure Database for PostgreSQL flexible server in the cluster's VNet.
- Azure Key Vault, where Complexio's credentials are stored. The `key_vault_id` and `key_vault_name` outputs give it.
- Azure Storage account for Complexio's object storage, reachable only through a private endpoint in the cluster's VNet (on by default).
- Workload identities for ExternalSecrets, ExternalDNS, CertManager, InferenceWorker and S3Proxy.
- A network appliance that all traffic in and out of the cluster goes through (`network_appliance`): a scale set of Linux VMs (default) or an Azure Firewall, with a static public IP (`network_appliance_public_ip_address` output). Or the customer's existing network appliance, such as a firewall: its [README](https://github.com/quintessential-ai/terraform-public/blob/main/terraform/recipes/complexio-cluster/README.public.md#traffic-through-the-customers-existing-network-appliance) lists what to set up on it before apply.
- Flux and ExternalSecrets deployed into the cluster.
- (Optional) Azure Bastion (`create_bastion`) to reach the private API server.
- (Optional) Child DNS zone (`dns_zone`). ExternalDNS may write only A, AAAA, CNAME and TXT records in it, and CertManager only TXT records.

### `recipes/entra-app-registrations`

Applied by a directory administrator rather than a subscription owner. Its [README](https://github.com/quintessential-ai/terraform-public/blob/main/terraform/recipes/entra-app-registrations/README.public.md) has the roles it needs, every switch, and the steps after apply.

- The Complexio - SSO and Complexio - Backend app registrations and enterprise applications in your Microsoft Entra tenant, with admin consent for the Microsoft Graph permissions of the features you switch on (`features`).
- Their certificates, client secrets and IDs, written to the Key Vault that `complexio-cluster` creates.
- Complexio's standard access groups, assigned to Complexio - SSO (on by default; `create_and_assign_access_groups`).
- The Complexio mailboxes administrative unit, and, with email features, the Exchange Online PowerShell that limits Complexio's mailbox access to its members.
- With Teams ingestion, Azure Event Hubs Data Receiver for Complexio - Backend on your Event Hubs namespace (`event_hub_namespace_id`), which may be in another subscription.
