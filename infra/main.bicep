// Main infrastructure file for API Translator Logic App
// This template creates a Logic App Standard with supporting services

@description('Location for all resources')
param location string = resourceGroup().location

@description('Integration Account ID for B2B operations')
param integrationAccountId string

@description('Existing Key Vault name for secrets storage')
param existingKeyVaultName string

@description('Existing managed identity name')
param existingManagedIdentityName string

@description('Resource group name where existing Key Vault and managed identity are located')
param existingResourceGroupName string

@description('App Service Plan name')
param appServicePlanName string

@description('Logic App name')
param logicAppName string

@description('App Service Plan SKU')
@allowed(['WS1', 'WS2', 'WS3'])
param appServicePlanSku string = 'WS1'

@description('App Service Plan tier')
param appServicePlanTier string = 'WorkflowStandard'

@description('Maximum elastic worker count for App Service Plan')
param maxElasticWorkerCount int = 20

@description('Target worker count for App Service Plan')
param targetWorkerCount int = 1

@description('Log Analytics workspace retention in days')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionDays int = 30

@description('Name of the existing storage account containing XSLT stylesheets')
param stylesheetStorageAccountName string = 'azdsab2binteus01'

// Generate unique resource token
// Resource names using the specified naming convention
var logAnalyticsWorkspaceName = 'az-d-law-b2bintegration-eus-00'
var applicationInsightsName = 'az-d-ai-b2bintegration-eus-00'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsRetentionDays
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Reference existing user-assigned managed identity
resource existingUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: existingManagedIdentityName
  scope: resourceGroup(existingResourceGroupName)
}

// Reference existing storage account for Logic App runtime and stylesheets
resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: stylesheetStorageAccountName
  scope: resourceGroup(existingResourceGroupName)
}

// Note: Role assignments for the existing storage account should be managed outside this deployment
// since the storage account is in a different resource group. 
// The managed identity already has Storage Blob Data Reader permissions granted via Azure CLI.

// Monitoring Metrics Publisher role assignment for managed identity
resource monitoringMetricsPublisherRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, existingUserAssignedIdentity.id, '3913510d-42f4-4e42-8a64-420c390055eb')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb') // Monitoring Metrics Publisher
    principalId: existingUserAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// App Service Plan for Logic App Standard
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'elastic'
  sku: {
    name: appServicePlanSku
    tier: appServicePlanTier
  }
  properties: {
    targetWorkerCount: targetWorkerCount
    maximumElasticWorkerCount: maxElasticWorkerCount
  }
}

// Logic App Standard (Function App with Logic App workflows)
resource logicApp 'Microsoft.Web/sites@2023-12-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${existingUserAssignedIdentity.id}': {}
    }
  }
  tags: {
    'azd-service-name': 'az-d-lap-ApiTranslator-eus-03'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      cors: {
        allowedOrigins: ['*']
        supportCredentials: false
      }
      use32BitWorkerProcess: false
      netFrameworkVersion: 'v6.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${existingStorageAccount.name};AccountKey=${existingStorageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${existingStorageAccount.name};AccountKey=${existingStorageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(logicAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'INTEGRATION_ACCOUNT_ID'
          value: integrationAccountId
        }
        {
          name: 'STYLESHEET_STORAGE_ACCOUNT'
          value: stylesheetStorageAccountName
        }
        {
          name: 'PARTNER_CONFIG_API_URL'
          value: '@Microsoft.KeyVault(SecretUri=https://${existingKeyVaultName}.vault.azure.net/secrets/PartnerConfigApiUrl/)'
        }
      ]
    }
  }
}

// Diagnostic settings for Logic App
resource logicAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'LogicAppDiagnostics'
  scope: logicApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs required for azd
@description('Resource Group ID')
output RESOURCE_GROUP_ID string = resourceGroup().id

@description('Logic App name')
output LOGIC_APP_NAME string = logicApp.name

@description('Logic App hostname')
output LOGIC_APP_HOSTNAME string = logicApp.properties.defaultHostName

@description('Application Insights connection string')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.properties.ConnectionString

@description('Storage account name')
output STORAGE_ACCOUNT_NAME string = existingStorageAccount.name

@description('Key Vault name')
output KEY_VAULT_NAME string = existingKeyVaultName

@description('User-assigned identity client ID')
output USER_ASSIGNED_IDENTITY_CLIENT_ID string = existingUserAssignedIdentity.properties.clientId
