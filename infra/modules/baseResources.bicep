targetScope = 'resourceGroup'

@description('Azure region for deployed resources.')
param location string

@description('Tags applied to every resource in this module.')
param resourceTags object

@description('Log Analytics workspace name.')
param logWorkspaceName string

@description('Azure Container Registry name.')
param containerRegistryName string

@description('Azure Container Apps managed environment name.')
param managedEnvironmentName string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logWorkspaceName
  location: location
  tags: resourceTags
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

var logWorkspaceKeys = listKeys(logWorkspace.id, '2020-08-01')

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
    }
  }
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: managedEnvironmentName
  location: location
  tags: resourceTags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logWorkspace.properties.customerId
        sharedKey: logWorkspaceKeys.primarySharedKey
      }
    }
  }
}

@description('Azure Container Registry login server.')
output acrLoginServer string = containerRegistry.properties.loginServer

@description('Azure Container Registry resource ID.')
output containerRegistryId string = containerRegistry.id

@description('Azure Container Apps managed environment name.')
output managedEnvironmentName string = managedEnvironment.name

@description('Azure Container Apps managed environment resource ID.')
output managedEnvironmentId string = managedEnvironment.id

@description('Log Analytics workspace resource ID.')
output logWorkspaceId string = logWorkspace.id
