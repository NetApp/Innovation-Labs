# Microsoft 365 Copilot

## Architecture

In Neo v4, Microsoft Graph integration is handled by the **Worker service**, which manages Graph connection creation, item uploads, ACL synchronization, and cleanup. The API service provides endpoints for configuring Graph credentials and monitoring sync status.

### Configuring Graph Credentials

Graph credentials can be configured in two ways:

1. **Environment variables**: Set `MS_GRAPH_CLIENT_ID`, `MS_GRAPH_CLIENT_SECRET`, and `MS_GRAPH_TENANT_ID` in the Worker and API service environment.

2. **Setup API**: Configure credentials at runtime via:
   ```
   POST /api/v1/setup/graph
   ```
   This is useful for initial setup or rotating credentials without restarting services.

### Register Neo as a connector in Azure Entra

In order for Neo to be able to securely communicate with M365 Copilot.

![Select App Registration in the Add menu in Microsoft Azure Entra](/neocore/2025-03-10_20-17-27.png)

1. Navigate to the Azure Entra portal and select "Add" and select the "App Registration" option.
2. Fill in the required fields and click "Register". (No Redirect URI is required)
3. Copy the Application (client) ID and Directory (tenant) ID from the Overview page.
4. Navigate to the "API permissions" page and select "Add a permission".
5. Select "Microsoft Graph" and then "Application permissions".
6. Search for "ExternalConnection.ReadWrite.OwnedBy" and select the checkbox.
7. Search for "ExternalItem.ReadWrite.OwnedBy" and select the checkbox.
8. Search for "User.Read" and select the checkbox.
9. Search for "User.Read.All" and select the checkbox.
10. Search for "Group.Read.All" and select the checkbox
11. Click "Add permissions".
12. Click "Graph admin consent for (tenant)" and click "Yes".
13. Navigate to the "Certificates & secrets" page and click "New client secret".
14. Fill in the required fields and click "Add".
15. Copy the value of the client secret.

You have successfully registered Neo as a connector in Azure ENTRA. You will need the **Application ID**, **Directory ID**, and **Client Secret** for the next steps.

## Graph Sync Monitoring

Neo provides API endpoints for monitoring and managing the Graph sync lifecycle for each share.

### Check sync status

```
GET /shares/{share_id}/graph/status
```

Returns the current Graph sync state for a share, including connection status, items uploaded, items pending, and any errors.

### Backfill items to Graph

```
POST /shares/{share_id}/graph/backfill
```

Triggers a backfill operation to upload any items that have been extracted but not yet synced to Microsoft Graph. Useful after initial setup or after resolving Graph connectivity issues.

### Clean up Graph items

```
POST /shares/{share_id}/graph/cleanup
```

Removes items from the Microsoft Graph connection that no longer exist in the source share. This is automatically performed during crawl operations but can be triggered manually.

### Retry failed uploads

```
POST /shares/{share_id}/graph/retry-failed
```

Retries all items that previously failed to upload to Microsoft Graph. Failed items are tracked in the database with error details for diagnostics.

## Managing the connector in M365 Admin Centre

Connectors can be managed via the M365 Admin Centre. This includes viewing connector status, managing data sources, and monitoring ingestion progress.

1. Navigate to the Microsoft 365 Admin Centre.
2. Select "Settings" and then "Microsoft 365 Copilot".
3. Select "Connectors" from the left-hand menu.
4. Here you can view all registered connectors, their status, and manage their settings.

[Microsoft 365 Admin Centre: Copilot Connectors](https://admin.cloud.microsoft/?source=applauncher#/copilot/connectors)

## Check item level permissions

You can validate the item level permissions that the connector has in M365 via the Index Browser within the M365 Admin Centre as shown below:

![M365 Admin Centre Index Browser showing item level permissions for the NetApp Neo connector](/neocore/2025-12-04_13-12-25.gif)

## Securing access to results

You can control access to the ingested data via Microsoft 365 Copilot by configuring the appropriate permissions in M365. This includes setting up role-based access control (RBAC) and ensuring that only authorized users can access the data ingested by the connector.

![M365 Admin Centre showing how to manage access to connector results](/neocore/2025-12-04_14-24-13.gif)

## Removing a connector

You can easily remove a connector and all of its indexed content from Microsoft 365 Copilot via the M365 Admin Centre as shown below:

![M365 Admin Centre showing how to remove a connector and all indexed content](/neocore/NetApp%20Neo%20-%20How%20to%20delete%20a%20connector.gif)
