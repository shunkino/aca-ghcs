# Azure Container Apps GitHub Actions sample

This repository provisions an Azure Container Apps environment with Bicep, builds a simple FastAPI service, and demonstrates how to continuously deliver new container images from GitHub Actions to Azure Container Apps using Azure Container Registry (ACR).

## Contents

- `infra/main.bicep` – creates an ACR instance, Log Analytics workspace, Container Apps managed environment, container app, and role assignment that grants the app access to pull images from ACR.
- `infra/dev.bicepparam` – default parameters for a `dev` environment.
- `src/app/main.py` – FastAPI endpoint that logs and returns the current UTC timestamp.
- `Dockerfile` – builds the application image and exposes port 8080.
- `.github/workflows/containerapp-deploy.yml` – GitHub Actions workflow that builds the image with `az acr build` and updates the container app revision.
- `.devcontainer/` – Codespaces/dev container definition with Python, Azure CLI, Bicep, and Docker tooling.

## Prerequisites

- Azure subscription with permission to create resource groups, Container Apps, and ACR.
- Latest [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) with the Container Apps extension (`az extension add --name containerapp`).
- Bicep CLI 0.26 or newer (included with current Azure CLI).
- Logged in via `az login` and set the target subscription (`az account set --subscription <id>`).

## Provision infrastructure

1. Choose a resource group (create one if needed):

   ```pwsh
   az group create --name rg-aca-demo --location eastus
   ```

2. Build and deploy the Bicep template. Update parameter values as needed or duplicate `infra/dev.bicepparam` for other environments.

   ```pwsh
   az deployment group create \
     --resource-group rg-aca-demo \
     --template-file infra/main.bicep \
     --parameters @infra/dev.bicepparam
   ```

   Record the outputs printed at the end of the deployment (`acrName`, `acrLoginServer`, `containerAppName`, `managedEnvironmentName`, `containerAppFqdn`, `containerImage`). You will reference these values later in GitHub.

> **Note**: The `containerImageTag` parameter must point at an image that exists in ACR. Run the GitHub Actions workflow once (or build locally with `az acr build`) to publish the initial tag referenced in the deployment.

## Configure GitHub Actions continuous deployment

1. Create a service principal with Contributor access scoped to the resource group:

   ```pwsh
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
     - `ACR_LOGIN_SERVER` – value of `acrLoginServer`.
     - `CONTAINER_APP_NAME` – value of `containerAppName`.
     - `AZURE_RESOURCE_GROUP` – the resource group name (for example `rg-aca-demo`).
     - `IMAGE_NAME` – container repository name (`timestamp-service` unless you changed `containerImageName`).

3. Trigger the workflow with **Actions → Build and Deploy Container App → Run workflow** or by pushing to `main`. Each run:
   - Builds the Dockerfile with `az acr build` and pushes a new image tagged with the first 12 characters of the commit SHA.
   - Updates the container app to pull the new image and sets the `APP_VERSION` environment variable to the same tag.
   - Prints the ingress FQDN for quick verification.

When the workflow completes, browse to `https://<containerAppFqdn>/` and you should see the current UTC timestamp along with the deployment metadata in the JSON response.

## Local development (Codespaces/dev container)

1. Open the repository in VS Code and run **Dev Containers: Reopen in Container** (or open in GitHub Codespaces).
2. The `postCreateCommand` installs project Python dependencies automatically. Start the app locally with:

   ```pwsh
   uvicorn app.main:app --host 0.0.0.0 --port 8080
   ```

3. Navigate to `http://localhost:8080` to inspect responses and logs before publishing.

## Clean up

Delete the resource group when finished to prevent additional charges:

```pwsh
az group delete --name rg-aca-demo --yes --no-wait
```

## Next steps

- Add additional environments by cloning `infra/dev.bicepparam` and creating unique GitHub variable sets per branch.
- Extend the workflow with automated tests before the deploy step.
- Integrate Azure Monitor alerts with the Log Analytics workspace provisioned by the template.
