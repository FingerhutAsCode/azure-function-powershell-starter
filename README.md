# Azure Function (PowerShell) — Starter Framework

A ready-to-use framework for building, testing, and deploying an Azure Function written in PowerShell. It includes a working HTTP-triggered function, local development tooling, infrastructure-as-code (Bicep) for provisioning Azure resources, and a GitHub Actions pipeline that deploys to Azure using secretless OIDC authentication.

## What's in this repository

| Path | Purpose |
|---|---|
| `HttpExample/` | Example HTTP-triggered function (`run.ps1` + `function.json`) |
| `host.json` | Function App host configuration |
| `profile.ps1` | Runs once per cold start of the PowerShell worker |
| `requirements.psd1` | Declares PowerShell module dependencies (e.g. `Az`) |
| `local.settings.json.example` | Template for local-only settings (copy to `local.settings.json`) |
| `tests/` | Pester unit tests for function logic |
| `infra/main.bicep` | Infrastructure-as-code to provision the Azure resources |
| `.github/workflows/deploy.yml` | CI/CD pipeline: builds and deploys to Azure on push to `main` |
| `.github/workflows/validate-pr.yml` | Lint/test validation that runs on pull requests (no deployment) |
| `docs/` | Detailed setup guides (see below) |

## Documentation map

This README covers the quick start. For deeper detail, see:

- **[docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md)** — installing tools and running/testing the function on your machine
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** — one-time Azure setup, OIDC federation, and how the GitHub Actions deployment works
- **[docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md)** — what the Bicep template provisions and how to run it
- **[docs/TESTING.md](docs/TESTING.md)** — running and writing Pester tests, plus manual HTTP testing
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — common errors and fixes

## Quick start

### 1. Use this repository as a template

Click **"Use this template"** on GitHub (or clone it), then clone your new repo locally:

```bash
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>
```

### 2. Set up local development

Install the prerequisites and run the function locally — full details in
[docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md). The short version:

```bash
# Copy the local settings template (this file is gitignored - never commit it)
cp local.settings.json.example local.settings.json

# Start the Functions host
func start
```

Then call the function:

```bash
curl "http://localhost:7071/api/HttpExample?Name=World"
```

### 3. Provision Azure resources

Use the included Bicep template to create the Function App, Storage Account,
and Application Insights instance. Full details in
[docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md). The short version:

```bash
az group create --name rg-myfunction --location eastus2

az deployment group create \
  --resource-group rg-myfunction \
  --template-file infra/main.bicep \
  --parameters functionAppName=<globally-unique-name>
```

### 4. Configure GitHub Actions to deploy automatically

This repo deploys using **OpenID Connect (OIDC)** — GitHub Actions authenticates to Azure using a short-lived federated token instead of a stored secret. This requires a one-time setup of an Azure Entra app registration (or managed identity) and federated credential, plus three GitHub repository secrets and one repository variable. Full step-by-step instructions are in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

Once set up, every push to `main` automatically builds, tests, and deploys the function to Azure.

## Architecture at a glance

```
Developer machine                GitHub                          Azure
------------------                ------                          -----
func start (local test)  --push-->  validate-pr.yml (on PR)
                                     deploy.yml (on push to main)
                                       |
                                       | OIDC token exchange (no secrets)
                                       v
                                     azure/login + Azure/functions-action
                                       |
                                       v
                                                                 Function App
                                                                 Storage Account
                                                                 Application Insights
```

## Requirements

- [Azure subscription](https://azure.microsoft.com/free/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [PowerShell 7.4+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- A GitHub repository with Actions enabled

See [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md) for installation instructions per OS.