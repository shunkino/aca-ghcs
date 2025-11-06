using './containerApp.bicep'

param projectName = 'aca-ghcs'
param targetEnv = 'dev'
param containerImageName = 'timestamp-service'
param containerImageTag = 'initial'
param resourceTags = {
  environment: 'dev'
  workload: 'aca-demo'
}
