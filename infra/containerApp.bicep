targetScope = 'resourceGroup'

@description('Project prefix used to build resource names.')
param projectName string

@description('Logical environment name (for example dev, qa, prod).')
param targetEnv string

@description('Container image repository name within ACR.')
param containerImageName string

@description('Image tag to deploy to the container app. Ensure this tag exists in the registry before running the template.')
param containerImageTag string

@description('Tags applied to the container app deployment.')
param resourceTags object = {}

@description('Azure region for the container app. Defaults to the resource group location.')
param location string = resourceGroup().location

var projectSegment = empty(trim(projectName)) ? 'aca' : toLower(replace(projectName, ' ', ''))
var envSegment = empty(trim(targetEnv)) ? 'env' : toLower(replace(targetEnv, ' ', ''))
var baseName = toLower(replace('${projectSegment}-${envSegment}', '--', '-'))
var namingSeed = uniqueString(subscription().id, resourceGroup().name)
var acrName = toLower(take('${replace(baseName, '-', '')}${namingSeed}', 50))
var managedEnvName = toLower(take('${baseName}-env', 63))
var containerAppName = toLower(take('${baseName}-app', 63))
var acrIdentityName = toLower(take('${baseName}-acr-mi', 63))

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: managedEnvName
}

resource acrPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: acrIdentityName
}

var containerImageReference = '${containerRegistry.properties.loginServer}/${containerImageName}:${containerImageTag}'

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: resourceTags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${acrPullIdentity.id}': {}
    }
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
          identity: acrPullIdentity.id
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

@description('Container app resource name.')
output containerAppName string = containerApp.name

@description('Fully qualified domain name for ingress.')
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn

@description('Default image reference configured on the container app.')
output containerImage string = containerImageReference

@description('User-assigned managed identity principal ID used for ACR pulls.')
output containerAppAcrPrincipalId string = containerApp.identity.userAssignedIdentities[acrPullIdentity.id].principalId
