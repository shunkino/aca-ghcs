@description('Project prefix used to build resource names.')
param projectName string = 'aca-ghcs'

@description('Logical environment name (for example dev, qa, prod).')
param targetEnv string = 'dev'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the container repository that holds the application image inside ACR.')
param containerImageName string = 'timestamp-service'

@description('Image tag to set on the container app after deployment. Ensure this tag exists in the registry before running the template.')
param containerImageTag string = 'initial'

@description('Tags applied to every resource in this deployment.')
param resourceTags object = {}

var sanitizedProject = toLower(replace(projectName, ' ', ''))
var sanitizedEnv = toLower(replace(targetEnv, ' ', ''))
var envSegment = empty(sanitizedEnv) ? 'env' : sanitizedEnv
var baseSegment = empty(sanitizedProject) ? 'aca' : sanitizedProject
var baseName = replace('${baseSegment}-${envSegment}', '--', '-')
var namingSeed = uniqueString(resourceGroup().id, projectName, targetEnv)
var acrPrefix = toLower(take(replace('${baseSegment}${envSegment}', '-', ''), 10))
var acrName = toLower(take('${acrPrefix}${namingSeed}', 50))
var logWorkspaceName = toLower(take('${baseName}-logs', 63))
var managedEnvName = toLower(take('${baseName}-env', 63))
var containerAppName = toLower(take('${baseName}-app', 63))

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
  name: acrName
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
  name: managedEnvName
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

var containerImageReference = '${containerRegistry.properties.loginServer}/${containerImageName}:${containerImageTag}'

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: resourceTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: managedEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'app'
          image: containerImageReference
          env: [
            {
              name: 'APP_NAME'
              value: projectName
            }
            {
              name: 'APP_ENVIRONMENT'
              value: targetEnv
            }
            {
              name: 'APP_VERSION'
              value: containerImageTag
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, containerApp.name, 'acrpull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: containerApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Deployed Azure Container Registry name.')
output acrName string = containerRegistry.name

@description('Azure Container Registry login server.')
output acrLoginServer string = containerRegistry.properties.loginServer

@description('Azure Container Apps managed environment name.')
output managedEnvironmentName string = managedEnvironment.name

@description('Container app resource name.')
output containerAppName string = containerApp.name

@description('Fully qualified domain name for ingress.')
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn

@description('Default image reference configured on the container app.')
output containerImage string = containerImageReference

@description('System-assigned managed identity principal ID for the container app.')
output containerAppPrincipalId string = containerApp.identity.principalId
