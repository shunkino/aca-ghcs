# Data Model: AI Engineer Progress Tracking

## Entities

### EngineerProfile
- **engineerId** (string, primary key): Unique ID aligned with Azure AD or GitHub handle.
- **displayName** (string): Human-readable name.
- **email** (string): Contact for notifications.
- **githubUsername** (string): GitHub handle used for API queries.
- **team** (string): Optional team or project grouping.
- **alertThresholds** (object): Configurable burnout indicators (e.g., max consecutive long days).
- **aiFoundryPersona** (string, optional): Prompt template identifier for personalized summaries.

### DailyProgressEntry
- **entryId** (string, primary key): Generated `engineerId + date` composite hash.
- **engineerId** (string, FK → EngineerProfile.engineerId).
- **date** (date): Report date (UTC day boundary).
- **submittedAt** (datetime): Precise submission timestamp.
- **reportText** (string): Engineer-authored narrative.
- **selfReportedMood** (enum): {`energized`, `steady`, `stressed`, `burned_out`, `not_set`}.
- **workloadScore** (int, 0-10): Self-estimated workload.
- **focusAreas** (string[]): Key tasks or priorities.
- **githubActivity** (object): Snapshot of GitHub metrics (see below).
- **aiTags** (string[]): Auto-generated tags (e.g., `high-focus`, `risk`).
- **ingestionState** (enum): {`pending`, `indexed`, `retrying`, `archived`}.
- **searchDocumentId** (string): Corresponding Azure AI Search document key.
- **failures** (array): Log of ingestion/aggregation failures with timestamps.

### GitHubActivity
- **commitCount** (int): Total commits authored on `date`.
- **pushCount** (int): Push operations executed for the engineer.
- **repositories** (array of objects): `{ name: string, commits: int }` per repository touched.
- **notableCommits** (array): Up to 5 highlighted commit messages/links.
- **collectedAt** (datetime): Timestamp of aggregation.
- **collectionState** (enum): {`pending`, `complete`, `partial`, `failed`}.

### IngestionRetry
- **retryId** (string, primary key): UUID for queue message.
- **entryId** (string): Associated DailyProgressEntry.
- **payload** (object): Serialized document ready for Azure AI Search.
- **attempts** (int): Number of retries already attempted.
- **nextVisibleAt** (datetime): When the message should be processed again.

### WellbeingSummary (materialized view for AI Foundry prompts)
- **summaryId** (string): `engineerId + date-range` identifier.
- **engineerId** (string, FK).
- **rangeStart** / **rangeEnd** (date): Analysis window.
- **generatedAt** (datetime): Time AI Foundry produced the summary.
- **summaryText** (string): Natural language insight.
- **riskLevel** (enum): {`normal`, `watch`, `critical`}.
- **sourceDocuments** (string[]): IDs of DailyProgressEntry documents referenced.

## Relationships

- `EngineerProfile 1 ── * DailyProgressEntry`
- `DailyProgressEntry 1 ── 1 GitHubActivity` (embedded document)
- `DailyProgressEntry 1 ── * IngestionRetry`
- `EngineerProfile 1 ── * WellbeingSummary`
- `WellbeingSummary * ── * DailyProgressEntry` (references captured in `sourceDocuments`)

## State Transitions

### DailyProgressEntry.ingestionState
1. **pending** → when new report stored locally.
2. **indexed** → after Azure AI Search confirms document upsert.
3. **retrying** → if ingestion fails; related `IngestionRetry` message enqueued.
4. **archived** → when older than 365 days; summary exported to Blob storage and AI Search document deleted.

Transitions: `pending → indexed`, `pending → retrying`, `retrying → indexed`, `indexed → archived`.

### GitHubActivity.collectionState
- `pending` → default when report created before GitHub aggregation.
- `complete` → metrics collected successfully.
- `partial` → some repositories retrieved before API error.
- `failed` → no data collected; triggers alert and retry policy.

## Derived Views

- **RecentRiskView**: Query combining last 7 days of `DailyProgressEntry` with `WellbeingSummary` risk levels to highlight engineers needing attention.
- **SubmissionGapView**: Detect missing entries by comparing expected dates from `EngineerProfile` working calendar against actual `DailyProgressEntry` records.
