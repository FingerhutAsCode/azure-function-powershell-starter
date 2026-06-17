# Infrastructure Guide

This repository includes a [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview)
template at `infra/main.bicep` that provisions everything the Function App
needs to run in Azure.

## What gets created

| Resource | Bicep symbolic name | Purpose |
|---|---|---|
| Storage Account | `storageAccount` | Required by every Azure Function App for trigger/binding state and deployment content |
| Application Insights | `appInsights` | Logs, metrics, and live tracing for the function |
| App Service Plan (Consumption, Windows, `Y1`) | `appServicePlan` | Pay-per-execution hosting plan |
| Function App | `functionApp` | The actual compute resource running your PowerShell code |

This template intentionally does **not** create the GitHub OIDC federated
credential or role assignment — that's an identity/authorization concern
handled in [docs/DEPLOYMENT.md](DEPLOYMENT.md), not a deployable ARM resource
in the usual sense (it's done via `az ad app federated-credential create`
and `az role assignment create`).

### Why Windows Consumption instead of Linux or Flex Consumption?

PowerShell on Azure Functions is best supported on **Windows**. Linux
Consumption is being phased out in favor of Flex Consumption, and Flex
Consumption has additional networking/deployment considerations. Windows
Consumption (`Y1` SKU) is the simplest, most broadly documented option for a
PowerShell function app and is what this starter targets. If you later need
Flex Consumption (for VNet integration, faster cold starts, or per-instance
memory tuning), see Microsoft's
[Flex Consumption Bicep samples](https://learn.microsoft.com/azure/azure-functions/flex-consumption-how-to)
and adapt `main.bicep` accordingly — the application code in `HttpExample/`
does not need to change.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and you've run `az login`
- An Azure subscription with permission to create resource groups and assign roles
- Bicep CLI (bundled with Azure CLI 2.20+; run `az bicep install` if needed)

## Deploying

### 1. Create a resource group

```bash
az group create --name rg-myfunction --location eastus2
```

### 2. (Optional) Validate before deploying

```bash
az deployment group validate \
  --resource-group rg-myfunction \
  --template-file infra/main.bicep \
  --parameters functionAppName=<globally-unique-name>
```

### 3. Preview changes with what-if

```bash
az deployment group what-if \
  --resource-group rg-myfunction \
  --template-file infra/main.bicep \
  --parameters functionAppName=<globally-unique-name>
```

### 4. Deploy

```bash
az deployment group create \
  --resource-group rg-myfunction \
  --template-file infra/main.bicep \
  --parameters functionAppName=<globally-unique-name>
```

> `functionAppName` must be **globally unique** across all of Azure, since it
> becomes part of the public hostname `<name>.azurewebsites.net`. If you get
> a "name already taken" error, pick a different name (e.g., add your org
> name or a random suffix).

Alternatively, use the parameters file at `infra/main.parameters.json` —
edit the placeholder value first, then run:

```bash
az deployment group create \
  --resource-group rg-myfunction \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

### 5. Capture the outputs

After deployment, the template outputs the function app's hostname and
resource ID:

```bash
az deployment group show \
  --resource-group rg-myfunction \
  --name main \
  --query properties.outputs
```

You'll need the Function App **name** (not the full hostname) for the
`AZURE_FUNCTIONAPP_NAME` GitHub variable described in
[docs/DEPLOYMENT.md](DEPLOYMENT.md).

## Customizing the template

Common adjustments:

- **Region:** change the `location` parameter (defaults to the resource group's region).
- **Storage redundancy:** change `storageAccountSku` (default `Standard_LRS`; use `Standard_GRS` for geo-redundancy in production).
- **Tags:** edit the `tags` parameter to match your organization's tagging policy (cost center, owner, environment, etc.).
- **Application settings:** add entries to the `appSettings` array in the `functionApp` resource if your function needs additional configuration (e.g., a connection string to another service).

## Tearing down

To delete everything this template created:

```bash
az group delete --name rg-myfunction --yes --no-wait
```

This deletes the Storage Account, Application Insights, App Service Plan,
and Function App. It does **not** delete the Entra app registration or
federated credential created in [docs/DEPLOYMENT.md](DEPLOYMENT.md) — those
live outside the resource group and need to be removed separately if you
want a full cleanup:

```bash
az ad app delete --id "$APP_ID"
```

## Updating infrastructure after initial deployment

Bicep deployments are idempotent — re-running `az deployment group create`
with the same template and parameters will only change what's different. To
update infrastructure (e.g., bump the storage SKU), edit `main.bicep` and
re-run the deploy command. This is a manual step in this starter; if you want
infrastructure changes to also flow through GitHub Actions automatically, you
could add a separate workflow that runs `az deployment group create` using
the same OIDC credential set up in [docs/DEPLOYMENT.md](DEPLOYMENT.md) — just
be aware that gives the GitHub identity broader permissions (it would need at
least `Contributor` at the resource group level, which it already has from
Step 4 of that guide).
