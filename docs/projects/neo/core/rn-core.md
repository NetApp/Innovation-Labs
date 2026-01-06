# Neo Core Release Notes

Neo Core is the container service responsible for the extraction and API operations of the service.

## Current Version

### 3.1.0 (Released 9th December 2025)

- **New**: FTE Search capabilities (new /search endpoint for agentic AI).
- **New**: Named Entity Recognition, Classification and Structured Data Extraction and Relation Extraction.
- **Enhancement**: Customers migrating from v3.0.5 or lower with pre-configured environmental variables will now experience automatic environment variable migration during setup mode and setup will be marked as complete.
- **Enhancement**: ACL resolution will now work in a greater variety of auth/security environments.
- **Fix**: Better detection of stale http transport to Graph API to prevent Graph Client Error: "HTTP transport has already been closed".
- **Fix**: Graph connector ID changes via hot-reload now correctly register new connectors in Microsoft 365.
- **Fix**: Changing the MS_GRAPH_CONNECTOR_ID no longer resets the CONNECTOR_ID used for licensing. This prevents license mismatch scenarios.

### 3.0.5 (Released 28th November 2025)

- **New** Neo search for agentic workflows is here (supports both PostgreSQL and MySQL databases). This returns the most relevant documents and content for agentic workflows from a query interface.
- **New:** Stateless container deployment - no environmental variables required to deploy the connector - (backward compatibility).
- **New:** Neo is now manageable via web interface (Note: desktop client is now no longer maintained).
- **Enhancement:** Threads are now dynamically calculated on start-up, providing optimal scaling and memory management. This provides significant performance enhancement for tasks, especially when more CPUs are available.
- **Enhancement:** The connector is now fully responsive, even during long running extraction tasks that would previously lock the task queue.
- **Enhancement:** Filters/Rules - Added a rolling window i.e. last 12 months to the date filters.
- **Enhancement:** One-time password retrieval via API:
  - Only active if admin has never logged in before
  - Disables once admin has logged in at least once
- **Enhancement:** Uninstall NetApp Neo API
  - Clear database to clean state
  - Remove connector from M365 Connectors (this automatically removes all items from M365 Graph)
- **Enhancement:** Neo no longer automatically attempts to continue an interrupted crawl upon reboot. Instead it will await the next scheduled crawl.
- **Fix:** Build date was not reflected correctly.

## Version History

### 3.0.4 (Released 22nd October 2025)

- **Enhancement:** Enhance use_client behavior for graph service client
- **Enhancement:** Management API responsiveness during long-running operations
- **Enhancement:** Newly implemented task scheduler allows cancellation and monitoring of all task operations
- **Enhancement:** Can view current performance metrics of all running tasks and estimate time to completion
- **Enhancement:** Reporting of share READY state has been restored to previous behaviour
- **Enhancement:** Allow pre-loading of document extraction models
- **Enhancement:** Helm chart now includes:
  - Optional database deployment (PostgreSQL)
- **Sizing Guidance**:
  - 15m per week ingest to Microsoft Graph  
     \- 2.1m items per day (100% utilization)
- **Fix:** Certain operation types not being reflected in database

### 2.2.6 (Released 22nd October 2025)

- **Enhancement:** SID ACL Resolution
- **Enhancement:** Graph HTTP Client Handling (for intermittent connectivity issues)
- **Fix:** Implement users API endpoint
- Note: This will be the last 2.x.x release. It is recommended to use the 3.x.x releases moving forward.

### 3.0.3 (Released 10th October 2025)

- **Enhancement:** Remove requirement for persistent storage for containers. All container configuration is now stored in database storage providing the following benefits:
  - ✅ **Automatic key sharing** - All nodes read from same database
  - ✅ **Easy scaling** - New nodes automatically get keys on start up
  - ✅ **Centralized management** - Update keys in one place
  - ✅ **Audit trail** - Track when keys are accessed/updated
  - ✅ **No volume required** - Truly stateless containers
  - ✅ **High availability** - Database replication handles redundancy
- **Enhancement:** Added graceful shutdown handling of claimed work items (immediately release items - previously these would be handled by timeout (5 mins)
- **Enhancement:** Implement Graph connector leader election logic
- **Enhancement:** Helm chart now includes:
  - Ingress configuration
  - Optional database-to-go (PostgreSQL / MySQL)
- **Enhancement:** User ACL resolution (Users are not resolving)
- **Fix:** files after initial scan (modified) or added were not being extracted
- Change **link** to **url** to allow direct click through on Copilot results tiles.

### 2.2.5 : (Released 8th October 2025)

- **Fix:** items were not being uploaded to MS Graph in certain scenarios
- **Fix:** ACL extraction
- **Important Note**: The 2.x.x code line is the last series to support internal database. As of 3.x.x an external database (**postgres/mysql**) is required for the connector

### 3.0.2 : (Released 7th October 2025)

- **Fix:** Stale share status if connector is interrupted during a prior run
- **Fix:** Changed file detection - in certain scenarios the connector incorrectly identified unchanged files as changes resulting in unnecessary extraction on those files