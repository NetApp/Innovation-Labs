# NetApp Connector User Quick Start Guide (v3.0+)

This guide assumes that you have deployed the NetApp connector and are ready to start using it. If you have not yet deployed the connector, please refer to the [NetApp Connector README](/C:/Program%20Files/Joplin/resources/app.asar/README.md "README.md").

> \[!IMPORTANT\]  
> The NetApp Connector for M365 Copilot is currently in **Private Preview**. This means that the connector is not yet fully supported and may have some limitations. The connector requires a license to activate. You can request access to the connector by joining the Early Access Program (EAP). Please book a meeting with the following link to join the EAP: [Book a meeting with NetApp](https://outlook.office.com/bookwithme/user/d636d7a02ad8477c9af9a0cbb029af4d@netapp.com/meetingtype/nm-mXkp-TUO1CdzOmFfIBw2?anonymous&ismsaljsauthenabled&ep=mlink).

## 1\. Getting Started

The easiest way to get started is by using the pre-built Docker image. You can run the connector in a Docker container or deploy it to a Kubernetes cluster using Helm.

```bash
docker pull ghcr.io/netapp/netapp-copilot-connector:latest
```

or for a specific version:

```bash
docker pull ghcr.io/netapp/netapp-copilot-connector:3.0.0
```

### Running the Container

1.  **Download the sample configuration files:**

    - Download the [Sample .env file](/C:/Program%20Files/Joplin/resources/app.asar/.env.example ".env.example") and rename it to `.env`
    - Download the [docker-compose.yml](/C:/Program%20Files/Joplin/resources/app.asar/docker-compose.yml "docker-compose.yml") file

2.  **Configure the `.env` file with the required environment variables:**

```bash
# NetApp Settings (Required)
NETAPP_CONNECTOR_LICENSE=your-licence-key-here

# Microsoft Graph configuration (Required)
MS_GRAPH_CLIENT_ID=your-client-id-here
MS_GRAPH_CLIENT_SECRET=your-client-secret-here
MS_GRAPH_TENANT_ID=your-tenant-id-here

# Database Configuration (Required- PostgreSQL is recommended)
## For PostgreSQL:
DATABASE_URL=postgresql://user:password@localhost:5432/netapp_connector
## or for MySQL:
DATABASE_URL=mysql://user:password@localhost:3306/netapp_connector

# Authentication (Optional - defaults provided)
JWT_SECRET_KEY=your-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# Multi-container deployments (Optional)
ENCRYPTION_KEY=your-shared-encryption-key
```

3.  **Run the connector using Docker Compose:**

```bash
docker-compose up -d
```

> \[!TIP\]  
> **GPU Acceleration Support**: The connector now supports GPU acceleration for faster document processing. Three variants are available:
>
> - `netapp-copilot-connector:latest` - CPU-only (smallest, ~2.5GB)
> - `netapp-copilot-connector:latest-cuda` - NVIDIA GPU support (~8GB)
> - `netapp-copilot-connector:latest-rocm` - AMD GPU support (~7GB)
>
> For GPU support, uncomment the `deploy` section in the `docker-compose.yml` file and ensure you have the appropriate GPU runtime installed.

### Using Helm

If you are using Kubernetes, you can deploy the connector using Helm. Please refer to the [Helm Deployment](/C:/Program%20Files/Joplin/resources/app.asar/charts/netapp-copilot-connector/README.md "charts/netapp-copilot-connector/README.md") document for more information.

### Database Options

**Version 3.0+ supports multiple database backends:**

- **PostgreSQL**: For production deployments with high availability (Recommended)
- **MySQL**: Alternative production database option

To use PostgreSQL or MySQL, set the `DATABASE_URL` environment variable:

```bash
# PostgreSQL example
DATABASE_URL=postgresql://user:password@localhost:5432/netapp_connector

# MySQL example
DATABASE_URL=mysql://user:password@localhost:3306/netapp_connector
```

## 2\. Initial Setup and First Admin User

> \[!IMPORTANT\]  
> A dedicated stand-alone desktop UI is available for Windows, MacOS and Linux: [Download the Desktop App](/C:/Program%20Files/Joplin/resources/app.asar/client "./client").

The easiest way to set up the connector and create your first admin user is through the desktop application. The desktop app provides a user-friendly interface for:

- User management
- Adding and configuring SMB shares
- Monitoring crawl progress
- Managing connector settings

Alternatively, you can use the API directly by accessing the interactive documentation at `http://localhost:8080/docs`

## 3\. Adding Your First Share

When configuring your first SMB share (either through the desktop app or API), you'll need to provide the following information:

### Required Configuration

- **Share Path**: The UNC path to your SMB share (e.g., `\\server\share`)
- **Authentication**: Domain username and password for accessing the share
- **Kerberos Settings**: Your Active Directory realm (e.g., `YOUR.REALM.DOMAIN`)
- **Crawl Schedule**: When to automatically scan for new/changed files (e.g., daily at 2 AM)

### File Processing Rules

Configure how the connector should process files in your share:

**File Filtering Options:**

- **Include Patterns**: Only process specific file types or paths (e.g., `*.pdf`, `*.docx`, `**/reports/**`)
- **Exclude Patterns**: Skip certain files or directories (e.g., `*.tmp`, `.git/*`, `**/temp/**`)
- **File Size Limits**: Set minimum and maximum file sizes to process

**Content Management:**

- **Copilot Upload**: Choose whether to upload files to Microsoft 365 Copilot for search
- **Content Persistence**: Decide whether to keep extracted content in the local database after upload

### Common Configuration Scenarios

**Scenario 1: Office Documents Only**

- Include patterns: `*.pdf`, `*.docx`, `*.xlsx`, `*.pptx`
- Enable Copilot upload for searchability

**Scenario 2: Database-Only Archive**

- Include specific file types or paths
- Disable Copilot upload to keep content local only

**Scenario 3: Full Share with Exclusions**

- Exclude temporary files, system folders, and backups
- Process all other content types

### New Rule Configuration Options (v3.0+)

- **`include_patterns`**: Only process files matching these patterns (mutually exclusive with `exclude_patterns`)
- **`exclude_patterns`**: Skip files matching these patterns
- **`persist_file_content`**: Keep extracted content in database after Graph upload (default: `true`)
- **`enable_copilot_upload`**: Upload files to Microsoft Graph/Copilot (default: `true`)

> \[!NOTE\]  
> **Pattern Filtering**: Use glob patterns like `*.pdf`, `**/*.docx`, or `**/reports/**`. You cannot use both `include_patterns` and `exclude_patterns` in the same share.

## 4\. Triggering Your First Crawl

After adding a share, you can trigger an immediate crawl to test the configuration and start indexing files:

### Starting a Crawl

- **Desktop App**: Use the "Start Crawl" button next to your configured share, or wait for the scheduled crawl to run
- **API**: Use the crawl endpoint for the specific share

### Monitoring Progress

You can monitor the crawl progress through:

- **Real-time Status**: View current crawl status, files processed, and any errors
- **Crawl Statistics**: See total files found, successfully processed, and completion time
- **Error Reporting**: Identify any files or directories that couldn't be accessed

### What Happens During a Crawl

1.  **Discovery**: The connector scans the share for files matching your configured rules
2.  **Content Extraction**: Text content is extracted from supported file types
3.  **ACL Processing**: File permissions are analyzed and mapped to Microsoft Entra users/groups
4.  **Upload**: Files are uploaded to Microsoft Graph (if enabled) for Copilot integration
5.  **Database Storage**: File metadata and content are stored in the local database

## 5\. Viewing Results in Microsoft 365 Copilot

> \[!WARNING\]  
> You must perform this step after you have added your first share and completed at least one successful crawl to see results in Microsoft 365 Copilot.

1.  **Visit the Microsoft 365 Admin Center**: Go to [Search and Intelligence](https://admin.microsoft.com/Adminportal/Home?source=applauncher#/MicrosoftSearch/connectors)
2.  **Enable Connector Results**: Ensure you have selected **_Include Connector Results_** for the NetApp Connector
3.  **Test in Microsoft 365 Copilot**: Try searching for content from your indexed files using natural language queries

![Select Include Connector Results in the Search and Intelligence Admin Centre](/C:/Program%20Files/Joplin/resources/app.asar/media/2025-07-15_09-47-23.png)

## 6\. New Features in Version 3.0+

### Enhanced Content Extraction

- **Docling Fallback**: Automatic fallback to Docling when MarkItDown fails to extract content from PDFs
- **GPU Acceleration**: Support for NVIDIA CUDA and AMD ROCm for faster document processing
- **Extractor Tracking**: Database tracks which extractor was used for each file

### Advanced Database Support

- **Multi-Database Support**: PostgreSQL (Recommended), and MySQL
- **Database Size Monitoring**: New `/database/size` endpoint for storage monitoring
- **Enhanced ACL Storage**: Stores both raw and resolved ACL information

### Improved Enumeration System

- **Rule Change Detection**: Automatically cleans up files that no longer match updated rules
- **Stale Record Cleanup**: Automatic cleanup of orphaned database records

### Enhanced Security & Compliance

- **ACL Strict Mode**: Control ACL fallback behavior with `ACL_STRICT_MODE` environment variable
- **Content Persistence Override**: Deployment-level control with `PERSIST_FILE_CONTENT_OVERRIDE`
- **Proxy Support**: Full proxy server support for corporate environments

### Monitoring & Operations

- **Health Monitoring**: Enhanced `/monitoring` endpoints for system status
- **Operation Logging**: Comprehensive operation tracking and logging
- **Share Deletion Cleanup**: Automatic Microsoft Graph cleanup when shares are deleted

## 7\. Troubleshooting Common Issues

### Authentication Issues

- Ensure `realm` matches your Active Directory domain exactly
- Verify `use_kerberos` is set to `"required"`
- Check that the user account has access to the SMB share

### Content Extraction Issues

- Check logs for extractor information
- For GPU acceleration, ensure proper GPU runtime is installed
- Verify file types are supported by the extractors

### Database Issues

- For multi-container deployments, ensure `ENCRYPTION_KEY` is set consistently across all nodes
- Monitor database size using the `/database/size` endpoint
- Check database connectivity if using PostgreSQL/MySQL

### Microsoft Graph Issues

- Verify all Graph API credentials are correct
- Check proxy configuration if behind corporate firewall
- Ensure connector is enabled in Microsoft 365 Admin Center

## 8\. Advanced Configuration

### Proxy Configuration

For corporate environments with proxy servers:

```bash
# HTTP/HTTPS proxy
HTTPS_PROXY=http://proxy.company.com:8080
HTTP_PROXY=http://proxy.company.com:8080

# Proxy authentication (optional)
PROXY_USERNAME=proxy_user
PROXY_PASSWORD=proxy_password

# SSL configuration
GRAPH_VERIFY_SSL=true
GRAPH_TIMEOUT=30
```

### SSL Inspection Firewalls

For environments with SSL inspection:

```bash
# Option 1: Disable SSL verification (less secure)
GRAPH_VERIFY_SSL=false

# Option 2: Custom CA bundle (recommended)
SSL_CERT_FILE=/app/data/custom_ca_bundle.pem
```

### Multi-Container Deployments

For high availability setups:

```bash
# Generate shared encryption key
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# Set in all containers
ENCRYPTION_KEY=your_generated_key_here
```

## 9\. API Access

The NetApp Connector provides a comprehensive REST API for programmatic access. The interactive API documentation is available at `http://localhost:8080/docs` after starting the connector.

For detailed API usage examples and advanced operations, please refer to our [API User Guide](/netapp-neo/USER_API_GUIDE.md).

## 10\. Firewall Permissions

If your organization's proxy or firewalls block communication to unknown domains, add the following rules to the 'allow' list:

| M365 Enterprise                              | M365 Government (GCC)                        | M365 GCCH                                                           |
| -------------------------------------------- | -------------------------------------------- | ------------------------------------------------------------------- |
| \*.office.com                                | \*.office.com                                | \*.office.com, \*.office365.us                                      |
| https://login.microsoftonline.com            | https://login.microsoftonline.com            | https://login.microsoftonline.com, https://login.microsoftonline.us |
| https://graph.microsoft.com/                 | https://graph.microsoft.com/                 | https://graph.microsoft.com/, https://graph.microsoft.us/           |
| https://huggingface.co/ds4sd/docling-models/ | https://huggingface.co/ds4sd/docling-models/ | https://huggingface.co/ds4sd/docling-models/                        |

## Support

If you have any feedback or questions regarding the NetApp Connector or its Documentation, please reach out to us by opening a GitHub issue at [NetApp Innovation Labs](https://github.com/NetApp/Innovation-Labs/issues).

---

**Version**: 3.0+  
**Last Updated**: September 2025
