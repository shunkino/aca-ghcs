# Quickstart: AI Engineer Progress Tracking Feature

## Prerequisites
- Azure subscription with permissions to create Azure AI Search, Storage Queue, and update existing Container App resources.
- Managed identity configured for the container app with roles:
  - `Search Index Data Contributor` on the AI Search service
  - `Storage Queue Data Contributor` on the storage account
- GitHub personal access token with `repo` scope stored as a secret (used if managed identity cannot reach GitHub Enterprise).
- Python tooling installed locally if running outside dev container (`pip`, `uv`, or `poetry`).

## Local Development
1. Launch the dev container or run `pip install -r requirements.txt`.
2. Set environment variables in `.env`:
   - `AI_SEARCH_ENDPOINT`
   - `AI_SEARCH_INDEX`
   - `AZURE_STORAGE_QUEUE`
   - `GITHUB_TOKEN` (optional for testing)
3. Start the FastAPI app: `uvicorn src.app.main:app --reload`.
4. Submit a test report:
   ```bash
   curl -X POST http://localhost:8000/api/v1/progress \
     -H "Content-Type: application/json" \
     -d '{"engineerId":"e1","date":"2025-11-12","reportText":"Focused on ingestion pipeline","selfReportedMood":"steady"}'
   ```
5. Run the GitHub sync task manually:
   ```bash
   curl -X POST http://localhost:8000/internal/v1/github-sync \
     -H "x-internal-key: local-dev" \
     -d '{"engineerId":"e1","date":"2025-11-12"}'
   ```
6. Verify ingestion logs in the console and confirm the document exists in Azure AI Search (`search explorer`).

## Azure Deployment
1. Extend `infra/main.bicep` and parameter files with AI Search service, index, and Storage Queue definitions.
2. Deploy: `az deployment group create -g <resource-group> -f infra/main.bicep -p infra/dev.bicepparam`.
3. Update GitHub Actions secrets:
   - `AZURE_CREDENTIALS`
   - `AI_SEARCH_ENDPOINT`
   - `AI_SEARCH_INDEX`
   - `AZURE_STORAGE_ACCOUNT`
   - `GITHUB_TOKEN` (if required)
4. Push to `001-ai-progress-tracking`; pipeline will build the container, push to ACR, and restart the Container App.
5. Validate the scheduler by checking Application Insights logs for `github_sync_job` events.

## AI Foundry Integration
1. Configure an AI Foundry project with a connection to the Azure AI Search index created above.
2. Create a prompt flow that uses the index as retrieval source and provides engineer ID/date range parameters.
3. Share the prompt flow with team leads; instruct them to pass engineer identifiers matching `EngineerProfile` entries.
4. Monitor response times and quality metrics captured by Application Insights custom events (`ai_foundry_request`).
