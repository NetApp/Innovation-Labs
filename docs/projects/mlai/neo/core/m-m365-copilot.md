# Microsoft 365 Copilot

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