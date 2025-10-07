# 3.0.3 (6/10/25)

- Fix: Changed file detection - in certain scenarios the connector incorrectly identified unchanged files as changes resulting in unnecessary extraction on those files

# 3.0.2 (6/10/25)

- Fix: Stale share status if connector is interrupted during a prior run

# 3.0.1 (2/10/25)

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
