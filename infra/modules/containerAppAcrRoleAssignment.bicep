targetScope = 'resourceGroup'

@description('Container registry name hosting the application image.')
param containerRegistryName string

@description('Deterministic name seed for the Container App.')
param containerAppName string

@description('System-assigned managed identity principal ID for the Container App.')
param principalId string

@description('Role definition to assign to the Container App identity.')
param roleDefinitionId string = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, roleDefinitionId, containerAppName, 'acrpull-system')
  scope: containerRegistry
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
