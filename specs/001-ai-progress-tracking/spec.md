# Feature Specification: AI Engineer Progress Tracking

**Feature Branch**: `001-ai-progress-tracking`  
**Created**: 2025-11-12  
**Status**: Draft  
**Input**: User description: "A. Use Azure AI search to store daily progress report for the engineer\nB. Report is written by engineer his self. Plus, GitHub information like commit / push of that engineer\nC. B will be collected by the program inside Azure Container App - already exist in curren project, so update the implementation in main.py to collect info daily\nD. Use AI Foundry to query ai search to review engineer's status - avoid burn out, track the status, etc"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Submit Daily Progress (Priority: P1)

An engineer submits a daily progress report through the existing application. The system stores the report in Azure AI Search so it can be queried later.

**Why this priority**: Capturing primary progress data is the foundation for all follow-up insights.

**Independent Test**: Verify that a report submitted through the API appears as a searchable document in Azure AI Search with the correct metadata.

**Acceptance Scenarios**:

1. **Given** an authenticated engineer and a daily progress payload, **When** the engineer submits the report, **Then** the system indexes the report in Azure AI Search within 1 minute.
2. **Given** the same engineer submits another report on the next day, **When** the new report is stored, **Then** Azure AI Search preserves both entries with distinct timestamps.

---

### User Story 2 - Aggregate GitHub Activity (Priority: P1)

A scheduled container app job collects each engineer's GitHub commits and pushes for the day and augments the daily report stored in Azure AI Search.

**Why this priority**: Automated activity capture gives richer context without extra manual effort.

**Independent Test**: Trigger the job with GitHub credentials and confirm that commit metadata for the target engineer is appended to the stored record.

**Acceptance Scenarios**:

1. **Given** valid GitHub access tokens, **When** the daily job runs, **Then** it writes commit counts, repository names, and commit messages for the engineer to Azure AI Search.
2. **Given** the GitHub API is temporarily unavailable, **When** the job runs, **Then** it records the failure and retries according to backoff policy without dropping previously stored data.

---

### User Story 3 - AI Review Dashboard (Priority: P2)

A lead uses AI Foundry to query Azure AI Search and receive an AI-generated summary of an engineer's wellbeing and workload to mitigate burnout.

**Why this priority**: Leadership insights close the loop between data collection and actionable feedback.

**Independent Test**: Run a prompt in AI Foundry connected to the index and confirm that the generated summary reflects the indexed data and highlights risk signals (e.g., excessive hours).

**Acceptance Scenarios**:

1. **Given** AI Foundry has search connector access, **When** the lead requests the latest status for an engineer, **Then** the generated summary references the engineer's most recent report and GitHub activity.
2. **Given** the engineer has multiple reports flagged as high stress, **When** the lead queries their status, **Then** the AI output surfaces burnout risk indicators.

---

### Edge Cases

- What happens when an engineer misses a day? The system should insert a placeholder entry signaling "no report" and still process GitHub activity if available.
- How does the system handle duplicate submissions? Subsequent submissions on the same day should either overwrite the earlier one or be merged while retaining activity history.
- How does the system respond when GitHub tokens expire? The job should log a credential error, notify maintainers, and skip updates until tokens are refreshed.
- What if AI Search ingestion is throttled? Data should queue locally and retry with exponential backoff.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an API endpoint for engineers to submit daily progress reports including narrative text and sentiment.
- **FR-002**: System MUST index each submitted report as a document in Azure AI Search with metadata (engineer ID, date, status).
- **FR-003**: System MUST schedule a daily job within the Azure Container App to query GitHub for the engineer's commits and pushes.
- **FR-004**: System MUST augment indexed reports with GitHub activity metrics (commit count, repositories touched, notable messages).
- **FR-005**: System MUST expose a retrieval workflow for AI Foundry to query Azure AI Search and compose a wellbeing summary.
- **FR-006**: System MUST log ingestion and aggregation outcomes for observability and troubleshooting.
- **FR-007**: System MUST provide a remediation path when external integrations (GitHub, AI Search, AI Foundry) fail (e.g., retry, alert).
- **FR-008**: System MUST authenticate requests to GitHub and Azure resources using managed identities where possible.
- **FR-009**: System MUST prevent duplicate daily entries per engineer unless explicitly allowed (configurable strategy).
- **FR-010**: System MUST ensure data retention aligns with organizational policy (NEEDS CLARIFICATION: retention duration).

### Key Entities

- **DailyProgressEntry**: Represents an engineer's daily narrative, mood, workload indicators, and associated GitHub metrics.
- **EngineerProfile**: Represents identity details, GitHub handles, alert thresholds, and AI Foundry access metadata.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of daily reports appear in Azure AI Search within 2 minutes of submission.
- **SC-002**: Automated GitHub aggregation completes successfully for 95% of scheduled runs per week.
- **SC-003**: AI Foundry queries return a synthesized status summary in under 30 seconds for 90% of requests.
- **SC-004**: Stakeholder feedback indicates the system helps identify potential burnout at least one day earlier in 80% of flagged cases (NEEDS CLARIFICATION: measurement method).
