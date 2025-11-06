# Azure Container Apps GitHub Actions sample

This repository provisions an Azure Container Apps environment with Bicep, builds a simple FastAPI service, and demonstrates how to continuously deliver new container images from GitHub Actions to Azure Container Apps using Azure Container Registry (ACR).

## Contents

- `infra/main.bicep` – subscription-scope template that creates the resource group, ACR instance, and supporting infrastructure.
- `infra/containerApp.bicep` – resource-group template that deploys the Container App once an image tag is available in ACR.
- `infra/dev.bicepparam` – default parameters for the shared infrastructure.
- `infra/dev-containerApp.bicepparam` – default parameters for the container app deployment.
- `src/app/main.py` – FastAPI endpoint that logs and returns the current UTC timestamp.
- `Dockerfile` – builds the application image and exposes port 8080.
- `.github/workflows/containerapp-deploy.yml` – GitHub Actions workflow that builds the image with `az acr build` and updates the container app revision.
- `.devcontainer/` – Codespaces/dev container definition with Python, Azure CLI, Bicep, and Docker tooling.

## Prerequisites

- Azure subscription with permission to create resource groups, Container Apps, and ACR.
- Latest [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) with the Container Apps extension (`az extension add --name containerapp`).
- Bicep CLI 0.26 or newer (included with current Azure CLI).
- Logged in via `az login` and set the target subscription (`az account set --subscription <id>`).

## Two-phase deployment

1. Deploy shared infrastructure (creates the resource group, ACR, Log Analytics workspace, and managed environment):

   ```bash
   az deployment sub create \
      --name aca-ghcs-shared \
      --location eastus \
      --template-file infra/main.bicep \
      --parameters infra/dev-main.bicepparam
   ```

2. Build and push the application image to ACR (ensure `<acrName>` matches the output from the previous step and choose a tag value such as `initial` or the commit SHA):

   ```bash
   az acr build \
      --registry <acrName> \
      --image timestamp-service:<tag> \
      --file Dockerfile \
      .
   ```

3. Deploy or update the Container App once the tag exists in ACR:

   ```bash
   az deployment group create \
      --name aca-ghcs-app-<tag> \
      --resource-group <resourceGroupName> \
      --template-file infra/containerApp.bicep \
      --parameters infra/dev-containerApp.bicepparam \
                   containerImageName=timestamp-service \
                   containerImageTag=<tag>
   ```

- Capture the outputs from both deployments (for example `acrName`, `containerAppName`, `containerAppFqdn`). They are useful for CI/CD configuration and verification.

## Build and deploy the container image manually

Use the same sequence whenever you need to publish a new revision manually:

1. Build and push the image: `az acr build ...`
2. Re-run the resource-group deployment with the updated `containerImageTag` value.
3. Verify the updated endpoint at `https://<containerAppFqdn>/`.

## Configure GitHub Actions continuous deployment

1. Create a service principal with Contributor access scoped to the resource group created by the subscription deployment:

   ```bash
   az ad sp create-for-rbac \
     --name aca-ghcs-sp \
     --role contributor \
     --scopes /subscriptions/<subscriptionId>/resourceGroups/rg-aca-demo \
     --sdk-auth
   ```

   Save the JSON output.

2. In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

    - Secret `AZURE_CREDENTIALS` → paste the JSON output from the previous step.
    - Variables (Actions → Variables → New repository variable):
       - `REGISTRY_NAME` – value of `acrName` from the deployment output.
       - `AZURE_RESOURCE_GROUP` – the resource group name created by the subscription deployment.
       - `IMAGE_NAME` – container repository name (`timestamp-service` unless you changed `containerImageName`).
       - `DEPLOYMENT_LOCATION` – region for subscription deployments (for example `eastus`).

3. Trigger the workflow with **Actions → Build and Deploy Container App → Run workflow** or by pushing to `main`. Each run:
   - Builds the Dockerfile with `az acr build`, pushing a tag derived from the commit SHA.
   - Deploys or refreshes the shared infrastructure via the subscription-scoped template.
   - Deploys the container app with the resource-group template, wiring up the new image tag automatically and printing the ingress FQDN.

When the workflow completes, browse to `https://<containerAppFqdn>/` and you should see the current UTC timestamp along with the deployment metadata in the JSON response.

## Local development (Codespaces/dev container)

1. Open the repository in VS Code and run **Dev Containers: Reopen in Container** (or open in GitHub Codespaces).
2. The `postCreateCommand` installs project Python dependencies automatically. Start the app locally with:

   ```bash
   export PYTHONPATH=$PWD/src
   uvicorn app.main:app --host 0.0.0.0 --port 8080
   ```

3. Navigate to `http://localhost:8080` to inspect responses and logs before publishing.

## Clean up

Delete the resource group when finished to prevent additional charges:

```bash
az group delete --name rg-aca-demo --yes --no-wait
```

## Next steps

- Add additional environments by cloning `infra/dev.bicepparam` and creating unique GitHub variable sets per branch.
- Extend the workflow with automated tests before the deploy step.
- Integrate Azure Monitor alerts with the Log Analytics workspace provisioned by the template.
