using './main.bicep'

param projectName = 'aca-ghcs'
param targetEnv = 'dev'
param location = 'eastus'
param containerImageName = 'timestamp-service'
param containerImageTag = 'initial'
param resourceTags = {
  environment: 'dev'
  workload: 'aca-demo'
}
