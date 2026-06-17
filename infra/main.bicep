// =============================================================================
// main.bicep
//
// Provisions the Azure resources required to host the PowerShell HTTP-triggered
// Function App in this repository:
//   - Storage Account (required by every Function App for triggers/bindings state)
//   - Application Insights (for logs/metrics)
//   - App Service Plan (Windows, Consumption / "Y1" SKU - pay-per-execution)
//   - Function App (Windows, PowerShell 7.4 worker, Functions runtime ~4)
//
// This template does NOT create the federated credential / OIDC trust between
// GitHub Actions and Azure - that is an identity-platform configuration step
// covered in docs/DEPLOYMENT.md, not an ARM/Bicep-deployable resource here.
//
// Deploy with:
//   az deployment group create \
//     --resource-group <your-rg> \
//     --template-file infra/main.bicep \
//     --parameters functionAppName=<globally-unique-name>
// =============================================================================

@description('Globally unique name for the Function App. Becomes part of the default *.azurewebsites.net hostname.')
@minLength(2)
@maxLength(60)
param functionAppName string

@description('Azure region for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('SKU for the storage account backing the Function App.')
param storageAccountSku string = 'Standard_LRS'

@description('Tags applied to all resources, useful for cost tracking and ownership.')
param tags object = {
  project: 'azure-function-powershell-starter'
}

var storageAccountName = 'st${uniqueString(resourceGroup().id, functionAppName)}'
var appServicePlanName = 'plan-${functionAppName}'
var appInsightsName = 'appi-${functionAppName}'
var functionWorkerRuntime = 'powershell'
var functionWorkerRuntimeVersion = '7.4'
var functionsExtensionVersion = '~4'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: false // false = Windows; PowerShell functions run on the Windows worker
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      powerShellVersion: functionWorkerRuntimeVersion
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionsExtensionVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: functionWorkerRuntimeVersion
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
  }
}

@description('The default hostname of the deployed Function App, e.g. my-func.azurewebsites.net')
output functionAppHostname string = functionApp.properties.defaultHostName

@description('The resource ID of the Function App - useful when wiring up RBAC or the GitHub federated credential subject.')
output functionAppResourceId string = functionApp.id

@description('The system-assigned managed identity principal ID for the Function App (for RBAC grants to other resources, not for GitHub OIDC).')
output functionAppPrincipalId string = functionApp.identity.principalId
