# NetApp Neo Connector Release Notes

## 3.0.4 (31-10-25)

- **Enhancement:** Enhance use_client behaviour for graph service client - this improves reliability of API calls to Microsoft Graph during intermittent network issues
- **Enhancement:** Management API responsiveness during long-running operations
- **Enhancement:** Newly implemented task scheduler allows cancellation and monitoring of all task operations
- **Enhancement:** Can view current performance metrics of all running tasks and estimate time to completion
- **Enhancement:** Reporting of share READY state has been restored to previous behaviour
- **Enhancement:** Streaming logs (real-time WebSocket/SSE)
- **Sizing Guidance**:
  - 15m per week ingest to Microsoft Graph
  - 2.1m items per day (100% utilization)
- **Fix:** Certain operation types not being reflected in database
- **Enhancement:** Improved ACL resolution logic and logging

## 2.2.5 (8-10-25)

- Fix: Fix: items were not being uploaded to MS Graph in certain scenarios

> \[!IMPORTANT\]  
>  The 2.x.x code line is the last series to support internal database. As of 3.x.x an external database (postgres/mysql) is required for the connector

## 3.0.2 (6/10/25)

- Fix: Changed file detection - in certain scenarios the connector incorrectly identified unchanged files as changes resulting in unnecessary extraction on those files
- Fix: Stale share status if connector is interrupted during a prior run

## 3.0.1 (2/10/25)

- Enhancement: Production support for MySQL database has been implemented
- Enhancement: Item ID between the local database and uploaded Copilot File ID is now universal
- Enhancement: ACL extraction implemented across all nodes of the platform
- Enhancement: Subdirectory scanning has been implemented
- Enhancement: Share rules enforcement has been implemented
- Fix: UNC path is correctly populated (was incorrectly populating as the relative file path)
- Fix: Deletion of a share will now remove all orphaned items from MS Graph
- Fix: Use correct icon on results
- Fix: users/me endpoint - this resulted in a missing user's section in the desktop app
- Fix: “get all users” endpoint
- Fix: MS_GRAPH_CONNECTOR name being incorrectly used as the ID for the connection in Microsoft 365 Copilot Connectors
- Enhancement: Users and groups ACL logic for matching based on latest API guidance
- Fix: Total extraction time was not calculated in the post-work-task summary
