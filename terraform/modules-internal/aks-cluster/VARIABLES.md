# aks-cluster variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| apiserver\_subnet\_cidr | Range of the aks-apiserver subnet, delegated to AKS for the private API server (API Server VNet Integration). A /27 at least. | `string` | n/a | yes |
| cluster\_name | Name of the AKS cluster; its identity is named after it. | `string` | n/a | yes |
| core\_pool\_vm\_size | Older or very new VM types are not available in every zone, which fails cluster creation. | `string` | n/a | yes |
| ingress\_lb\_subnet\_cidr | Range of the aks-ingress-lb subnet, for the gateway's internal load balancer. A /29 at least: Azure reserves five addresses in every subnet, and the gateway takes the fifth. | `string` | n/a | yes |
| network\_appliance\_ip | Private IP of the network appliance that takes all the nodes' egress. It must be reachable before the cluster is created: its nodes need egress to start. | `string` | n/a | yes |
| nodes\_subnet\_cidr | Range of the aks-nodes subnet, which the core node pool and, by default, Karpenter provision into. A /24 at least. | `string` | n/a | yes |
| region | Region of the cluster. Must match the VNet's. | `string` | n/a | yes |
| resource\_group\_name | Resource group the cluster and, unless an existing VNet is used, the VNet live in. | `string` | n/a | yes |
| vnet\_id | VNet the subnets are created in. The cluster identity is granted Network Contributor on it. | `string` | n/a | yes |
| acr\_ids | Container registries the kubelet may pull images from, keyed by a plan-time-stable name. | `map(string)` | `{}` | no |
| availability\_zones | Every Azure region with availability zones names them "1", "2" and "3". | `list(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |
| core\_pool\_node\_count | Nodes in the core node pool, which does not autoscale. | `number` | `2` | no |
| core\_pool\_os\_disk\_size\_gb | OS disk size of each core node, in GB. It also holds the container images and emptyDir volumes. | `number` | `128` | no |
| dns\_prefix | It sets the prefix for the cluster's Fully Qualified Domain Name. If empty, it defaults to the resource\_group\_name. | `string` | `null` | no |
| dns\_service\_ip | Cluster IP of the cluster's DNS service. Must be in service\_cidr. | `string` | `"172.17.255.254"` | no |
| enable\_azure\_container\_storage | Local NVMe-backed storage for pods, e.g. fast model loading on GPU nodes. | `bool` | `true` | no |
| kubernetes\_version | Kubernetes version of the control plane and the core node pool. AKS picks its default version when null. | `string` | `null` | no |
| node\_provisioning\_mode | "Auto" hands node provisioning to Karpenter (NAP); "Manual" uses node pools only. | `string` | `"Auto"` | no |
| pod\_cidr | Range the pods take their IPs from. With Azure CNI Overlay it is not part of the VNet's address space. | `string` | `"172.16.0.0/16"` | no |
| principal\_ids | Entra group object IDs to grant each AKS built-in role to. | <pre>object({<br/>    cluster_admin = optional(list(string), [])<br/>    admin         = optional(list(string), [])<br/>    writer        = optional(list(string), [])<br/>    reader        = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| private\_cluster\_enabled | Keep the API server private. Set false only for internal development clusters. | `bool` | `true` | no |
| service\_cidr | Range the Kubernetes Services take their cluster IPs from. | `string` | `"172.17.0.0/16"` | no |
| sku\_tier | Control-plane SKU tier: Free, Standard or Premium. | `string` | `"Standard"` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
| tenant\_id | Entra tenant backing the cluster's AAD integration. Defaults to the provider's own tenant. | `string` | `null` | no |
<!-- END_TF_DOCS -->
