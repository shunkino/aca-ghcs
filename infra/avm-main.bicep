targetScope = 'subscription'

@description('Project prefix used to build resource names.')
param projectName string = 'aca-ghcs'

@description('Logical environment name (for example dev, qa, prod).')
param targetEnv string = 'dev'

@description('Azure region used for the deployment.')
param location string = deployment().location

@description('Name of the resource group to create before deploying resources.')
param resourceGroupName string = '${projectName}-${targetEnv}-rg'

@description('Name of the container repository inside ACR.')
param containerImageName string = 'timestamp-service'

@description('Tag for the container image. Ensure this image tag already exists in ACR before deployment.')
param containerImageTag string = 'initial'

@description('Tags applied to every resource in this deployment.')
param resourceTags object = {}

var projectSegment = empty(trim(projectName)) ? 'aca' : toLower(replace(projectName, ' ', ''))
var envSegment = empty(trim(targetEnv)) ? 'env' : toLower(replace(targetEnv, ' ', ''))
var baseName = toLower(replace('${projectSegment}-${envSegment}', '--', '-'))
var namingSeed = uniqueString(subscription().id, resourceGroupName)
var acrName = toLower(take('${replace(baseName, '-', '')}${namingSeed}', 50))
var logWorkspaceName = toLower(take('${baseName}-logs', 63))
var managedEnvName = toLower(take('${baseName}-env', 63))
var containerAppName = toLower(take('${baseName}-app', 63))

resource targetRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: resourceTags
}

module sharedResources 'modules/baseResources.bicep' = {
  name: 'sharedResources'
  scope: targetRg
  params: {
    location: location
    resourceTags: resourceTags
    logWorkspaceName: logWorkspaceName
    containerRegistryName: acrName
    managedEnvironmentName: managedEnvName
  }
}

module containerApp 'br/public:avm/res/app/container-app:0.19.0' = {
  name: 'containerApp'
  scope: targetRg
  params: {
    name: containerAppName
    location: location
    tags: resourceTags
    environmentResourceId: sharedResources.outputs.managedEnvironmentId
    managedIdentities: {
      systemAssigned: true
    }
    registries: [
      {
        server: sharedResources.outputs.acrLoginServer
        identity: 'system'
      }
    ]
    ingressExternal: true
    ingressAllowInsecure: false
    ingressTargetPort: 8080
    containers: [
      {
        name: 'app'
        image: '${sharedResources.outputs.acrLoginServer}/${containerImageName}:${containerImageTag}'
        resources: {
          cpu: json('0.25')
          memory: '0.5Gi'
        }
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
      }
    ]
    scaleSettings: {
      minReplicas: 1
      maxReplicas: 3
    }
  }
}

var containerAppSystemPrincipalId = containerApp.outputs.?systemAssignedMIPrincipalId ?? ''

module containerAppAcrPull 'modules/containerAppAcrRoleAssignment.bicep' = {
  name: 'containerAppAcrPull'
  scope: targetRg
  params: {
    containerRegistryName: acrName
    containerAppName: containerAppName
    principalId: containerAppSystemPrincipalId
  }
}

@description('Resource group name created for the deployment.')
output resourceGroupName string = resourceGroupName

@description('Azure Container Registry name.')
output acrName string = acrName

@description('Azure Container Registry login server.')
output acrLoginServer string = sharedResources.outputs.acrLoginServer

@description('Log Analytics workspace name.')
output logWorkspaceName string = logWorkspaceName

@description('Managed environment name.')
output managedEnvironmentName string = sharedResources.outputs.managedEnvironmentName

@description('Container App name.')
output containerAppName string = containerApp.outputs.name

@description('Container App ingress FQDN.')
output containerAppFqdn string = containerApp.outputs.fqdn

@description('Container App system-assigned principal ID, when enabled.')
output containerAppPrincipalId string = containerAppSystemPrincipalId

@description('Container image reference used by the app.')
output containerImage string = '${sharedResources.outputs.acrLoginServer}/${containerImageName}:${containerImageTag}'
