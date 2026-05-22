# Employee Portal — Azure Reference Architecture

A production-ready employee directory application on Azure, built with enterprise security controls from day one.

## Architecture

```
Internet
   │
   ├─► Azure Static Web Apps (CDN-fronted React SPA)
   │       │  REACT_APP_API_URL (build-time)
   │       ▼
   └─► Azure Function App  (HTTPS, CORS locked to SWA origin)
           │  VNet Integration (outbound)
           │  System-Assigned Managed Identity
           ▼
       Virtual Network (10.0.0.0/16)
           ├─ snet-private-endpoints (10.0.1.0/24)
           │       ├─► Cosmos DB  [private endpoint]
           │       └─► Key Vault  [private endpoint]
           └─ snet-function-app   (10.0.2.0/24, delegated)
```

### Technology choices

| Layer | Choice | Rationale |
|---|---|---|
| Frontend | React 18 + TypeScript | Widely adopted, strong ecosystem, build-time env injection for API URL |
| Backend | Azure Functions v4 (Node 20) | Serverless, native managed-identity support, fast cold starts on EP1 |
| Database | Cosmos DB SQL API | JSON-native, globally distributed, fine-grained RBAC, strong SDK |
| Hosting | Static Web Apps (Standard) | Global CDN, free TLS, GitHub Actions integration |
| IaC | Terraform ~> 3.100 | Declarative, module-based, mature AzureRM provider |

## Security Controls

| Control | Implementation |
|---|---|
| No passwords or connection strings | Cosmos DB `local_authentication_disabled = true`; Function App uses `DefaultAzureCredential` |
| Managed Identity | System-assigned identity on the Function App; granted Cosmos DB Built-in Data Contributor role |
| Private Endpoints | Cosmos DB and Key Vault have no public internet exposure |
| VNet Integration | Function App routes all outbound traffic through the VNet (EP1 plan required) |
| HTTPS Only | Enforced on Function App; SWA is HTTPS by default |
| CORS | Locked to the Static Web App's CDN hostname |
| NSGs | Applied to both subnets |
| Key Vault RBAC | `enable_rbac_authorization = true`; no legacy access policies |
| No wildcard CORS | CORS `allowed_origins` is set to the specific SWA hostname |
| CI with OIDC | GitHub Actions uses federated credentials — no client secrets stored |

> **Production hardening checklist** (not enabled by default to keep costs reasonable):
> - Enable `purge_protection_enabled = true` on Key Vault
> - Add Azure AD EasyAuth to the Function App
> - Enable Cosmos DB multi-region writes and configure failover
> - Move Terraform state to an Azure Storage backend

## Terraform Module Structure

```
terraform/
├── providers.tf          # AzureRM ~> 3.100, random
├── variables.tf
├── main.tf               # Root module — wires modules together, cross-module RBAC
├── outputs.tf
├── terraform.tfvars.example
└── modules/
    ├── networking/       # VNet, subnets, NSGs, private DNS zones
    ├── cosmos_db/        # Account, DB, container, private endpoint
    ├── key_vault/        # Vault, private endpoint, deployer RBAC
    ├── function_app/     # Storage, App Insights, service plan, Function App
    └── static_web_app/   # SWA resource
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.50
- [Node.js](https://nodejs.org/) >= 20
- [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local) v4
- An Azure subscription with Contributor + User Access Administrator on the target scope

## Deploying

### 1 — Authenticate

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2 — Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set project_name, environment, location
```

### 3 — Provision infrastructure

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Save the outputs:

```bash
terraform output function_app_url      # e.g. https://func-empportal-dev-xxxx.azurewebsites.net/api
terraform output static_web_app_url   # e.g. https://proud-sky-xxxx.azurestaticapps.net
```

### 4 — Deploy the backend

```bash
cd ../backend
npm install
npm run build
func azure functionapp publish "$(cd ../terraform && terraform output -raw function_app_name)"
```

### 5 — Seed sample data

Call the seed endpoint once using its function key (get it from the Azure Portal → Function App → Functions → seedData → Function Keys):

```bash
curl -X POST \
  "https://<func-name>.azurewebsites.net/api/seed?code=<function-key>"
```

### 6 — Deploy the frontend

```bash
cd ../frontend
REACT_APP_API_URL="$(cd ../terraform && terraform output -raw function_app_url)" npm run build

# Deploy via SWA CLI or Azure portal upload
npm install -g @azure/static-web-apps-cli
swa deploy ./build \
  --deployment-token "$(cd ../terraform && terraform output -raw static_web_app_deployment_token)"
```

The portal is now live at the `static_web_app_url` output.

## Local Development

### Backend

```bash
cd backend
cp local.settings.json.example local.settings.json
# Fill in COSMOS_ENDPOINT (use Cosmos Emulator or run `az login` for live account)
npm install
npm start        # starts func host on http://localhost:7071
```

### Frontend

```bash
cd frontend
echo "REACT_APP_API_URL=http://localhost:7071/api" > .env.local
npm install
npm start        # starts dev server on http://localhost:3000
```

## CI/CD

The GitHub Actions workflow (`.github/workflows/deploy.yml`) uses OIDC federation so no client secrets are stored in GitHub:

1. **Terraform** — provisions / updates infrastructure, captures outputs
2. **Deploy backend** — builds TypeScript, publishes to Function App
3. **Deploy frontend** — builds React with `REACT_APP_API_URL` from Terraform output, deploys to SWA

Required GitHub secrets:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | Service principal / managed identity client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

The service principal needs: **Contributor** + **User Access Administrator** on the subscription (or resource group), and a federated credential for the GitHub Actions OIDC issuer.

## Key Design Decisions & Trade-offs

**Why EP1 instead of Consumption?**
Regional VNet integration (required for outbound traffic to reach private endpoints) is only supported on Elastic Premium and Dedicated plans. Flex Consumption supports it but is newer and has different scaling behaviour. EP1 gives predictable performance with auto-scale.

**Why Cosmos DB SQL API instead of Mongo/Cassandra?**
SQL API is the most mature, has the best Terraform support, and the `@azure/cosmos` SDK has first-class TypeScript types. The partition key `/department` means department-scoped queries hit a single partition.

**Why is the Function App publicly accessible?**
Cosmos DB is completely private (no internet path). The Function App is the controlled ingress point; adding a private endpoint to it would require Azure API Management or Azure Front Door Premium as the edge proxy, significantly increasing cost and complexity for this use case. In production, add EasyAuth (Azure AD) to require authentication at the Function App level.

**Why `local_authentication_disabled = true` on Cosmos DB?**
This forces all callers to use Entra ID tokens. Even if someone obtained the account endpoint URL, they cannot authenticate without a valid managed identity or service principal. There are literally no keys to leak.

**Why Static Web Apps instead of App Service / Storage static hosting?**
SWA is purpose-built for SPAs: global CDN, automatic TLS, atomic deployments, and native GitHub Actions integration. The Standard tier adds custom domain with managed certificates.
