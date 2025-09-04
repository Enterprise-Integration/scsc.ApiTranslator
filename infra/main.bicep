// Main infrastructure file for API Translator Logic App
// This template creates a Logic App Standard with supporting services

@description('Environment name to use as a suffix for all resources')
param environmentName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Resource prefix for naming (max 3 characters)')
@maxLength(3)
param resourcePrefix string = 'atr'

@description('Integration Account ID for B2B operations')
param integrationAccountId string

@description('Storage connection string for stylesheets')
param stylesheetStorageConnection string = ''

@description('Partner configuration API URL')
param partnerConfigApiUrl string = ''

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

@description('Storage account type')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Premium_LRS'])
param storageAccountType string = 'Standard_LRS'

@description('Storage account tier')
@allowed(['Hot', 'Cool'])
param storageAccountTier string = 'Hot'

// Generate unique resource token
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)

// Resource names using the specified naming convention
var logAnalyticsWorkspaceName = 'az-${resourcePrefix}-law-${resourceToken}'
var applicationInsightsName = 'az-${resourcePrefix}-ai-${resourceToken}'
var storageAccountName = 'az${resourcePrefix}st${resourceToken}'

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

// Storage Account for Logic App
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    accessTier: storageAccountTier
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// Note: Key Vault Secret Officer role assignment should be managed outside this deployment
// since the Key Vault is in a different resource group. This can be done manually or via a separate deployment.

// Storage Blob Data Owner role assignment for managed identity
resource storageBlobDataOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, existingUserAssignedIdentity.id, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
    principalId: existingUserAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor role assignment for managed identity
resource storageBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, existingUserAssignedIdentity.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: existingUserAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Queue Data Contributor role assignment for managed identity
resource storageQueueDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, existingUserAssignedIdentity.id, '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    principalId: existingUserAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Table Data Contributor role assignment for managed identity
resource storageTableDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, existingUserAssignedIdentity.id, '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3') // Storage Table Data Contributor
    principalId: existingUserAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

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
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
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
          name: 'STYLESHEET_STORAGE_CONNECTION'
          value: stylesheetStorageConnection
        }
        {
          name: 'PARTNER_CONFIG_API_URL'
          value: partnerConfigApiUrl
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
output STORAGE_ACCOUNT_NAME string = storageAccount.name

@description('Key Vault name')
output KEY_VAULT_NAME string = existingKeyVaultName

@description('User-assigned identity client ID')
output USER_ASSIGNED_IDENTITY_CLIENT_ID string = existingUserAssignedIdentity.properties.clientId
