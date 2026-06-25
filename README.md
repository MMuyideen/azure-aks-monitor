# Azure AKS Monitor

A cloud infrastructure project that provisions a production-ready **Azure Kubernetes Service (AKS)** cluster using Terraform, then deploys the **Bank of Anthos** microservices application as a workload to validate and monitor the environment.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
  - [1. Bootstrap Remote State Storage](#1-bootstrap-remote-state-storage)
  - [2. Configure Variables](#2-configure-variables)
  - [3. Provision Infrastructure](#3-provision-infrastructure)
  - [4. Deploy Bank of Anthos](#4-deploy-bank-of-anthos)
- [Terraform Modules](#terraform-modules)
- [Bank of Anthos Application](#bank-of-anthos-application)
- [Teardown](#teardown)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    Azure Subscription                     │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Resource Group (var.rgname)          │   │
│  │                                                  │   │
│  │   ┌─────────────┐   ┌──────────────────────┐    │   │
│  │   │ Service     │   │   AKS Cluster         │    │   │
│  │   │ Principal   │──▶│   deen-aks-cluster    │    │   │
│  │   │ (AzureAD)   │   │   Standard_DS2_v2     │    │   │
│  │   └─────────────┘   │   Auto-scale: 1–3     │    │   │
│  │                     │   Zones: 1, 3         │    │   │
│  │   ┌─────────────┐   │   Network: Azure CNI  │    │   │
│  │   │  Key Vault  │   └──────────────────────┘    │   │
│  │   │  (RBAC)     │                                │   │
│  │   └─────────────┘                                │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │    tf-week5-state-rg  (Terraform Remote State)   │   │
│  │    Storage Account: tfpracticestorageweek5        │   │
│  │    Container:        tfpracticecontainer          │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | Latest | Authenticate & bootstrap state storage |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.0 | Provision Azure infrastructure |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Latest | Interact with AKS cluster |
| [Skaffold](https://skaffold.dev/docs/install/) | Latest | Build & deploy Bank of Anthos |
| SSH key pair | — | Node pool access (`~/.ssh/host_key.pub` by default) |

Ensure you are logged in to Azure before running any commands:

```bash
az login
az account set --subscription "<your-subscription-id>"
```

---

## Project Structure

```
azure-aks-monitor/
├── starter-script.sh           # Creates Azure Storage backend for Terraform state
├── Terraform/
│   ├── main.tf                 # Root module — wires together all sub-modules
│   ├── providers.tf            # azurerm 3.114.0 + azuread 2.53.1
│   ├── backend.tf              # Azure Storage remote state configuration
│   ├── variables.tf            # Input variable declarations
│   ├── output.tf               # Outputs: RG name, SP client ID & secret
│   └── modules/
│       ├── ServicePrincipal/   # AzureAD app registration + service principal
│       ├── aks/                # AKS cluster + kubeconfig generation
│       └── keyvault/           # Azure Key Vault with RBAC
└── bank-of-anthos/             # Sample microservices app (9 services)
    ├── kubernetes-manifests/   # K8s deployment manifests
    ├── src/                    # Application source code (Python + Java)
    ├── iac/                    # GKE/Anthos Terraform configs
    └── docs/                   # Deployment & architecture guides
```

---

## Getting Started

### 1. Bootstrap Remote State Storage

Before running Terraform, create the Azure Storage Account that will hold the remote state file:

```bash
bash starter-script.sh
```

This creates:
- Resource group: `tf-week5-state-rg` (East US)
- Storage account: `tfpracticestorageweek5`
- Blob container: `tfpracticecontainer`

> **Note:** This only needs to be run once per Azure subscription.

---

### 2. Configure Variables

Create a `terraform.tfvars` file inside the `Terraform/` directory:

```hcl
rgname                 = "my-aks-resource-group"
location               = "eastus"
service_principal_name = "my-aks-sp"
keyvault_name          = "my-aks-keyvault"
ssh_public_key         = "~/.ssh/id_rsa.pub"
```

| Variable | Description | Default |
|----------|-------------|---------|
| `rgname` | Name of the Azure Resource Group to create | — |
| `location` | Azure region | `eastus` |
| `service_principal_name` | Name for the AzureAD service principal | — |
| `keyvault_name` | Globally unique name for the Key Vault | — |
| `ssh_public_key` | Path to SSH public key for node access | `~/.ssh/host_key.pub` |

---

### 3. Provision Infrastructure

```bash
cd Terraform

# Initialize providers and backend
terraform init

# Preview changes
terraform plan -var-file="terraform.tfvars"

# Apply
terraform apply -var-file="terraform.tfvars"
```

After a successful apply, a `kubeconfig` file is generated in `Terraform/` and the following outputs are displayed:

| Output | Description |
|--------|-------------|
| `resource_group_name` | Name of the provisioned resource group |
| `client_id` | Service principal application (client) ID |
| `client_secret` | Service principal credential (sensitive) |

Configure `kubectl` to use the new cluster:

```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

---

### 4. Deploy Bank of Anthos

The Bank of Anthos manifests are designed for Kubernetes and can be applied directly to the AKS cluster.

```bash
kubectl apply -f bank-of-anthos/kubernetes-manifests/
```

Alternatively, use Skaffold for a full build-and-deploy cycle:

```bash
cd bank-of-anthos
skaffold run
```

Access the frontend once the LoadBalancer IP is assigned:

```bash
kubectl get svc frontend
```

---

## Terraform Modules

### `modules/ServicePrincipal`

Creates an AzureAD application registration and service principal with a generated password. The SP is granted **Contributor** role at the subscription scope and is used by the AKS cluster for Azure resource operations.

### `modules/aks`

Provisions the AKS cluster with the following configuration:

| Setting | Value |
|---------|-------|
| Cluster name | `deen-aks-cluster` |
| VM size | `Standard_DS2_v2` |
| Node count | Auto-scale 1–3 |
| Availability zones | 1, 3 |
| Network plugin | Azure CNI |
| Load balancer | Standard |
| Kubernetes version | Latest available |

Outputs a local `kubeconfig` file for immediate `kubectl` access.

### `modules/keyvault`

Provisions an Azure Key Vault with:
- Standard SKU
- Azure RBAC authorization model
- 7-day soft-delete retention
- Disk encryption enabled

---

## Bank of Anthos Application

Bank of Anthos is a polyglot microservices reference application simulating a retail banking platform.

| Service | Language | Role |
|---------|----------|------|
| `frontend` | Python | Web UI — login, signup, transfers |
| `user-service` | Python | Account management & JWT auth |
| `contacts` | Python | User contact list |
| `ledger-writer` | Java | Transaction validation & writes |
| `balance-reader` | Java | Cached balance reads |
| `transaction-history` | Java | Cached transaction reads |
| `accounts-db` | PostgreSQL | User accounts store |
| `ledger-db` | PostgreSQL | Transaction ledger store |
| `loadgenerator` | Python/Locust | Synthetic load generation |

See [bank-of-anthos/docs/](bank-of-anthos/docs/) for advanced deployment options including Cloud SQL, Workload Identity, and Anthos Service Mesh.

---

## Teardown

To destroy all Azure resources provisioned by Terraform:

```bash
cd Terraform
terraform destroy -var-file="terraform.tfvars"
```

To remove the remote state storage (run after `terraform destroy`):

```bash
az group delete --name tf-week5-state-rg --yes --no-wait
```

> **Warning:** Deleting the state storage before `terraform destroy` will cause Terraform to lose track of managed resources.
