# Research Findings

## Scheduler Selection for Daily Aggregation
- **Decision**: Embed an APScheduler-based daily job inside the FastAPI app, triggered via a background task when the container starts.
- **Rationale**: Keeps orchestration within the existing service as requested, leverages Python-native scheduling, and works with Azure Container Apps' always-on behavior. APScheduler supports cron-style triggers and retry hooks without additional Azure resources.
- **Alternatives Considered**:
  - *Azure Container Apps Jobs*: Provides managed scheduling but would require provisioning a separate job resource and deployment pipeline changes, diverging from the "program inside the existing app" requirement.
  - *Azure Logic Apps / Functions Timer*: Adds more services and authentication flows, increasing operational overhead for a simple daily trigger.

## Reliability Buffer for AI Search Ingestion
- **Decision**: Implement an in-app retry queue backed by Azure Storage Queue for failed AI Search ingestion attempts.
- **Rationale**: Azure Storage Queue is lightweight, integrates with managed identities, and persists transient failures without building a bespoke retry system. It also allows manual replay via scripts if needed.
- **Alternatives Considered**:
  - *In-memory retry list*: Would lose events during restarts and does not satisfy durability needs.
  - *Service Bus*: More features but unnecessary for low-volume, once-per-day ingestion, and introduces extra costs.

## Scale Assumptions
- **Decision**: Design for up to 500 engineers submitting daily reports with a roadmap to shard indexes when approaching 1,000 users.
- **Rationale**: Covers the stated pilot (<100 users) with headroom, keeps AI Search within S1 tier limits, and informs index partition sizing.
- **Alternatives Considered**:
  - *Unlimited scaling target*: Unnecessary complexity now; would require multi-index federation earlier.
  - *Pilot-only scope*: Risks rework once additional teams enroll.

## Data Retention Policy
- **Decision**: Retain AI Search documents for 365 days, then archive summary metrics to Azure Blob Storage before deletion.
- **Rationale**: One-year history supports performance and wellbeing trend analysis while bounding storage costs. Archiving summaries preserves long-term insights without retaining detailed text indefinitely.
- **Alternatives Considered**:
  - *Indefinite retention*: Raises compliance/cost concerns.
  - *90-day retention*: Too short to identify seasonal trends or burnout patterns.

## Success Criteria Measurement
- **Decision**: Instrument the app to emit Application Insights custom metrics tracking ingestion SLAs and AI Foundry response times, and gather qualitative feedback via a quarterly survey of leads.
- **Rationale**: Provides quantifiable data to validate SC-001 to SC-003 and a consistent survey instrument for SC-004.
- **Alternatives Considered**:
  - *Manual spreadsheet tracking*: Error-prone and hard to automate.
  - *Rely solely on AI Foundry analytics*: Lacks full coverage of ingestion reliability and user sentiment.
