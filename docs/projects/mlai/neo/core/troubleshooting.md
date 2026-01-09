# Troubleshooting

## How to log a support case / idea

Please log support cases or ideas via the NetApp Innovations Labs issues portal: [Innovation Labs Issues](https://github.com/NetApp/Innovation-Labs/issues).

## Container won't start

This typically occurs when the connector does not have a valid license key. Ensure that the `NETAPP_CONNECTOR_LICENSE` environment variable is set in the .env file and that the license key is valid.

## Frequently Asked Questions (FAQ)

### What is the NetApp Neo: Connector for M365 Copilot?

The NetApp Neo: Connector for M365 Copilot is a containerized solution that enables you to connect any NetApp platform to Microsoft M365 Copilot without the need to migrate files or rearchitect your existing data architecture. The connector is deployed as a containerized solution and provides an API interface for easy integration and management of the connector. The connector supports enhanced filtering, parallelization, and large document chunking.

### What are the supported sources for the NetApp Neo: Connector for M365 Copilot?

The NetApp Neo: Connector for M365 Copilot supports the following sources:

- SMB File Shares (v3.1.1 through v2.0). SMB 3.1.1 is recommended for optimal performance due to multi-channel support and performance improvements over prior SMB versions. This includes:
  - Azure NetApp Files (ANF)
  - AWS FSxN
  - Google Cloud Volumes NetApp (GCVN)
  - Cloud Volumes ONTAP (CVO)
  - Any ONTAP-based system (FAS, AFF, Select, etc.)

### What about non-NetApp sources?

The NetApp Neo: Connector for M365 Copilot is designed to work at protocol level and is not specifically locked to NetApp platforms. Please reach out to your NetApp representative for more information.

### How is the NetApp Neo: Connector for M365 Copilot licensed?

The NetApp Neo: Connector for M365 Copilot is licensed per licensed user of M365 Copilot. The license is perpetual and includes 1 year of support and maintenance. The license is tied to the connector and is not transferable. The license does not require an internet connection for activation.

### Does the NetApp Neo: Connector for M365 Copilot support multiple file shares?

Yes, the NetApp Neo: Connector for M365 Copilot supports multiple file shares. You can configure multiple file shares in the connector and manage them through the API interface. A shares API endpoint is available for managing and monitoring the file shares. Theoretically, there is no limit to the number of file shares that can be connected to the connector. In a real-world deployment, the number of file shares that can be connected to the connector is limited by the performance of the connector and the underlying storage system and as such should be tested in early testing before deploying to production.

### How do I upgrade the NetApp Neo: Connector for M365 Copilot?

Simply pull the latest image from the repository and redeploy the connector. The connector will automatically upgrade to the latest version. Please ensure that you have a valid license key for the connector.

### The connnector starts, then stops immediately

This typically occurs when the connector does not have a valid license key. Ensure that the `NETAPP_CONNECTOR_LICENSE` environment variable is set in the .env file and that the license key is valid.

### How does Microsoft 365 Copilot work for organizations with multiple regions?

All graph data is stored in the **Primary Provisioned Geography** location. This applies even if an organization has satellite regions, as explained here [Plan for Microsoft 365 Multi-Geo - Microsoft 365 Enterprise | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/enterprise/plan-for-multi-geo?view=o365-worldwide) but the graph index is only in the primary region (in order to provide a unified search experience across all the tenants).
