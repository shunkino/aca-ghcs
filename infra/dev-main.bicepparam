using './main.bicep'

param projectName = 'aca-ghcs'
param targetEnv = 'dev'
param location = 'eastus'
param resourceTags = {
  environment: 'dev'
  workload: 'aca-demo'
}
