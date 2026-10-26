# complexio-cluster

Creates the network, the private AKS cluster and the Azure resources Complexio runs on in the
customer's subscription. This page covers sending the cluster's traffic through the customer's own
network appliance.

## Traffic through the customer's existing network appliance

The network appliance is a firewall, or any other appliance the customer uses to manage inbound
and outbound traffic. With `use_existing_network_appliance = true`, all traffic from the
cluster's nodes leaves through it, and the cluster gets no public IP. The appliance forwards
HTTPS from its public IP to the cluster's private load balancer.

Decide before the cluster is created: `use_existing_network_appliance` cannot be switched on an
existing cluster.

### Address ranges

The cluster's address ranges follow `vnet_cidr` and must not overlap the customer's networks.
With the default `10.224.0.0/16`:

| Range | Default | Used for |
| --- | --- | --- |
| Nodes subnet | `10.224.0.0/24` | Source of all egress |
| `aks-ingress-lb` subnet | `10.224.5.0/24` | The cluster's private load balancer |
| Private load balancer IP | `10.224.5.4` | Where the appliance forwards HTTPS (`ingress_lb_private_ip` output) |

### Before `terraform apply`

The cluster's nodes cannot start until these are in place.

1. **AKS egress.** The appliance allows HTTPS from `10.224.0.0/24` to the addresses AKS needs:
   [AKS outbound network rules](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress).
   On Azure Firewall, add a rule collection to the firewall's policy: Azure portal →
   **Firewall Policies** → the policy → **Settings** → **Application rules** →
   **Add a rule collection**:
   - Name `aks-egress`, type **Application**, priority `200`, action **Allow**.
   - Rule `aks`: source type **IP Address**, source `10.224.0.0/24`, protocol `https:443`,
     destination type **FQDN Tag**, destination `AzureKubernetesService`. FQDN Tag rules only
     take HTTPS.

   The new rule collection is then listed and the policy's provisioning state is **Succeeded**.
2. **Peering rights.** Terraform peers the appliance's VNet with the cluster's VNet, both ways.
   Whoever runs Terraform needs **Network Contributor** on the appliance's VNet. The appliance's
   VNet may be in another subscription of the same tenant: set
   `existing_network_appliance_subscription_id` then.

Then set in the tfvars:

```hcl
use_existing_network_appliance        = true
existing_network_appliance_private_ip = "<appliance private IP>"
existing_network_appliance_vnet_id    = "<appliance VNet resource ID>"
# Only when the appliance's VNet is in another subscription:
existing_network_appliance_subscription_id = "<appliance VNet subscription ID>"
```

After apply, point the application DNS records at the appliance's public IP.
