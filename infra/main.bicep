targetScope = 'subscription'

@description('Project prefix used to build resource names.')
param projectName string = 'aca-ghcs'

@description('Logical environment name (for example dev, qa, prod).')
param targetEnv string = 'dev'

@description('Azure region used for the new resource group and its resources.')
param location string = deployment().location

@description('Name of the resource group to create before deploying resources.')
param resourceGroupName string = '${projectName}-${targetEnv}-rg'

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
var acrIdentityName = toLower(take('${baseName}-acr-mi', 63))

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
    acrIdentityName: acrIdentityName
  }
}

@description('Deployed Azure Container Registry name.')
output acrName string = acrName

@description('Azure Container Registry login server.')
output acrLoginServer string = sharedResources.outputs.acrLoginServer

@description('Azure Container Registry resource ID.')
output containerRegistryId string = sharedResources.outputs.containerRegistryId

@description('Azure Container Apps managed environment name.')
output managedEnvironmentName string = sharedResources.outputs.managedEnvironmentName

@description('Azure Container Apps managed environment resource ID.')
output managedEnvironmentId string = sharedResources.outputs.managedEnvironmentId

@description('Log Analytics workspace name.')
output logWorkspaceName string = logWorkspaceName

@description('Log Analytics workspace resource ID.')
output logWorkspaceId string = sharedResources.outputs.logWorkspaceId

@description('Derived container app resource name.')
output containerAppName string = containerAppName

@description('User-assigned managed identity name for ACR pulls.')
output acrIdentityName string = acrIdentityName

@description('User-assigned managed identity resource ID for ACR pulls.')
output acrIdentityId string = sharedResources.outputs.acrIdentityId

@description('Resource group name created for the deployment.')
output resourceGroupName string = resourceGroupName
