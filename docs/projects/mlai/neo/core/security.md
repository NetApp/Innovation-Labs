# NetApp Project Neo - Security Documentation

## Overview

NetApp Project Neo is a secure enterprise application that indexes content from file shares (SMB, NFS, S3) across any storage vendor. It provides an MCP (Model Context Protocol) server for AI assistants to search and retrieve indexed content with ACL-based access control, and optionally integrates with Microsoft Graph to enable Microsoft 365 Copilot access. Neo can be deployed in MCP-only mode where all data and indexes remain entirely on-premises. This document provides comprehensive security information for security teams evaluating the application's architecture, implementation, and security controls.

## Application Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐
│   Microsoft     │    │   Microsoft      │
│   365 Copilot   │◄──►│   Graph API      │
│                 │    │   (Optional)     │
└─────────────────┘    └──────────────────┘
                              ▲
                              │ HTTPS
                              ▼
┌─────────────┐  ┌──────────────────────────────────────────────────────────┐
│ MCP Clients │  │  neo-network (Docker bridge)                            │
│ (AI tools)  │  │                                                          │
└──────┬──────┘  │  ┌──────────┐  ┌────────┐  ┌────────┐  ┌────────────┐  │
       │         │  │   API    │  │ Worker │  │  NER   │  │ Extractor  │  │
       │ HTTPS   │  │  :8000   │─►│(intern)│─►│(intern)│  │  (intern)  │  │
       └────────►│  └────┬─────┘  │        │  │GLiNER2 │  │GPU-accel.  │  │
                 │       │        └───┬────┘  └────────┘  └────────────┘  │
┌─────────────┐  │       │            │              ▲            ▲        │
│  Neo UI     │  │       │            │              └────────────┘        │
│  :8081      │──►       │            │          Worker orchestrates       │
└─────────────┘  │       ▼            │                                    │
                 │  ┌──────────┐      │                                    │
                 │  │PostgreSQL│      │                                    │
                 │  │  :5432   │      │                                    │
                 │  └──────────┘      │                                    │
                 └────────────────────┼────────────────────────────────────┘
                                      │
                                      │ SMB/NFS/S3
                                      ▼
                       ┌──────────────────────────────┐
                       │  File Shares                 │
                       │  (NetApp, third-party, any   │
                       │   SMB/NFS/S3 storage vendor) │
                       └──────────────────────────────┘
```

> [!NOTE]
> **MCP-only deployment**: Microsoft Graph integration is optional. When deployed without Graph, Neo operates as a standalone MCP server where all data, indexes, and search remain entirely on-premises. No content is uploaded to Microsoft cloud services.

### Microservices

Neo v4 is composed of four microservices communicating over an internal Docker network (`neo-network`):

1. **API Service** (port 8000): FastAPI application handling REST API, MCP server, authentication, and share management. Exposed externally.
1. **Neo UI** (port 8081): Web-based management console (separate container: `ghcr.io/beezy-dev/neo-ui-framework`). Connects to the API service internally. Exposed externally.
2. **Worker Service** (internal only): Background service that crawls file shares, enumerates directories, processes work queue items, and uploads content to Microsoft Graph.
3. **Extractor Service** (internal only): GPU-accelerated document content extraction using Docling. Converts files (PDF, DOCX, PPTX, etc.) to markdown for indexing.
4. **NER Service** (internal only): Named Entity Recognition using GLiNER2 for entity extraction, document classification, and structured data extraction from indexed content.
5. **Database Layer**: PostgreSQL (primary) or MySQL for metadata, user accounts, work queues, and operational logs.
6. **Security Manager**: Shared library (`netapp_shared/security/`) providing authentication, encryption, OAuth validation, and access control across all services.

### Firewall Rules

If your organization's proxy or firewalls block communication to unknown domains, add the following rules to the 'allow' list. The Microsoft 365 domains are only required when Microsoft Graph integration is enabled; MCP-only deployments only need HuggingFace access for initial model downloads:

| M365 Enterprise                              | M365 Government (GCC)                       | M365 GCCH                                                           |
| -------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------- |
| \*.office.com                                | \*.office.com                               | \*.office.com, \*.office365.us                                      |
| https://login.microsoftonline.com            | https://login.microsoftonline.com           | https://login.microsoftonline.com, https://login.microsoftonline.us |
| https://graph.microsoft.com/                 | https://graph.microsoft.com/                | https://graph.microsoft.com/, https://graph.microsoft.us/           |
| https://huggingface.co/ds4sd/docling-models/ | https://huggingface.co/ds4sd/docling-models | https://huggingface.co/ds4sd/docling-models                         |

## Security Architecture

### Authentication & Authorization

Neo supports multiple authentication mechanisms depending on the access path.

#### JWT-Based Authentication (Admin UI / REST API)

- **Algorithm**: HS256 (HMAC with SHA-256)
- **Token Expiration**: Configurable via `ACCESS_TOKEN_EXPIRE_MINUTES` (default: 24 hours / 1440 minutes)
- **Secret Key Management** (priority order):
  1. `JWT_SECRET_KEY` environment variable (highest priority)
  2. Database-stored key in `system_config` table (recommended for multi-node)
  3. Legacy file-based storage (`data/jwt_secret.key`, auto-migrated to database)
  4. Auto-generated 256-bit key stored in database if none exists
- **Internal Service Token**: Deterministic token derived from JWT secret for MCP-to-API internal calls (localhost only)

#### OAuth 2.0 / Microsoft Entra ID (MCP Server)

The MCP server supports OAuth 2.0 authentication via Microsoft Entra ID for AI assistant integrations:

- **Token Format**: RS256-signed JWT tokens issued by Microsoft Entra ID
- **Validation**: Tokens validated against Entra ID JWKS (JSON Web Key Set) endpoint with key caching
- **Claims Extracted**: `sub`, `oid` (Object ID), `tid` (Tenant ID), `name`, `preferred_username`, `email`, `groups`, `roles`
- **Group Membership**: Fetched from Microsoft Graph API and cached (TTL-based)
- **ACL Enforcement**: User's Entra group memberships mapped against SMB/NFS ACLs to filter search results per-user
- **Legacy SSL Support**: Configurable support for certificates without keyUsage X.509 extension (Python 3.13+), custom CA bundle injection for corporate proxies

**Environment variables:**

```bash
MCP_OAUTH_ENABLED=true
MCP_OAUTH_TENANT_ID=<entra-tenant-id>
MCP_OAUTH_CLIENT_ID=<oauth-client-id>
MCP_OAUTH_CLIENT_SECRET=<oauth-client-secret>
MCP_OAUTH_AUDIENCE=<expected-token-audience>
```

#### MCP API Key Authentication

For CLI tools, automation, and environments where OAuth is not practical, Neo supports static API key authentication that bypasses the OAuth flow:

- **Configuration**: Set via `MCP_API_KEY` environment variable or stored encrypted in the database (`mcp.api_key` config key)
- **Comparison**: Constant-time comparison using `secrets.compare_digest` to prevent timing attacks
- **Identity Mapping**: Configurable identity via `MCP_API_KEY_EMAIL`, `MCP_API_KEY_NAME`, `MCP_API_KEY_SUB` environment variables (or database equivalents)
- **ACL Mode**: Configurable default ACL mode (`MCP_DEFAULT_ACL_MODE`) controls access when no user principal can be resolved

#### User Management

- **Password Hashing**: bcrypt with 12 rounds (configurable)
- **User Roles**: Standard users and administrators
- **Account Management**: Create, authenticate, and manage user accounts
- **Session Management**: JWT tokens with configurable expiration

#### API Security

- **OAuth2 Bearer Token**: Standard OAuth2 implementation for REST API and MCP endpoints
- **Protected Endpoints**: All administrative and data access endpoints require authentication
- **Role-Based Access**: Admin-only endpoints for user management and system configuration
- **MCP Rate Limiting**: Per-tool rate limits configurable via environment variables (`MCP_RATE_LIMIT_SEARCH`, `MCP_RATE_LIMIT_CONTENT`, `MCP_RATE_LIMIT_TOTAL`, etc.)

### Data Encryption

#### At-Rest Encryption

- **Database**: PostgreSQL with filesystem-level encryption support
- **Credential Storage**: SMB/NFS passwords and OAuth secrets encrypted using Fernet (AES-128 in CBC mode with HMAC authentication)
- **Key Management** (priority order):
  1. `ENCRYPTION_KEY` environment variable (highest priority, recommended for multi-node)
  2. Database-stored key in `system_config` table (auto-generated if not present)
  3. Legacy file-based storage (`data/key.key`, auto-migrated to database on first use)
  4. Auto-generated Fernet key stored in database if none exists
- **Key Format**: 256-bit URL-safe base64-encoded Fernet keys
- **Sensitive Config**: The `system_config` table supports `is_sensitive` flag and `config_type='secret'` for encryption keys, JWT secrets, and other sensitive values

#### In-Transit Encryption

- **HTTPS**: Application designed to run behind HTTPS proxy/load balancer
- **Microsoft Graph API**: All communications over HTTPS
- **SMB Connections**: Supports SMB encryption when available on target shares
- **Internal Services**: Services communicate over Docker bridge network (`neo-network`); TLS termination at the ingress layer

### Access Control & Permissions

#### SMB Share Access

- **Authentication**: Username/password or Kerberos authentication
- **ACL Processing**: Extracts and processes Windows ACLs from SMB shares
- **Principal Resolution**: Maps SMB principals to Microsoft Entra (Azure AD) objects
- **Permission Inheritance**: Respects Windows file system permissions

#### MCP ACL Filtering

- **Per-Request Filtering**: MCP search results filtered based on the authenticated user's Entra group memberships
- **Default ACL Mode**: Configurable (`MCP_DEFAULT_ACL_MODE`): `deny` (default, deny access when no principal resolved) or `allow`
- **Share-Level Config**: Per-share ACL configuration stored in database

#### Microsoft Graph Integration (Optional)

Microsoft Graph integration is optional. It is only required when using Neo with Microsoft 365 Copilot. MCP-only deployments do not require Graph credentials and keep all data on-premises.

- **Service Principal Authentication**: Uses Azure AD application credentials
- **Scoped Permissions**: Requires specific Graph API permissions for connector operations
- **ACL Mapping**: Translates SMB ACLs to Microsoft Graph external item permissions

### Network Security

#### Service Architecture & Ports

| Service   | Port | Exposure      | Purpose                                  |
| --------- | ---- | ------------- | ---------------------------------------- |
| API       | 8000 | External      | REST API and MCP server                  |
| UI        | 8081 | External      | Web administration interface              |
| Worker    | --   | Internal only | File crawling, Graph sync, work queue    |
| Extractor | 8000 | Internal only | Document content extraction (GPU)        |
| NER       | 8000 | Internal only | Named entity recognition (GPU)           |
| PostgreSQL| 5432 | Internal only | Database                                 |

#### Container Security (Per-Service)

Each microservice runs with the minimum privileges required for its function:

| Service   | User          | Capabilities                           | Privileged | Notes                                        |
| --------- | ------------- | -------------------------------------- | ---------- | -------------------------------------------- |
| API       | netapp (1000) | None required                          | No         | Minimal privileges                           |
| Worker    | netapp (1000) | SYS_ADMIN, DAC_READ_SEARCH, DAC_OVERRIDE | No      | Required for SMB/NFS mounting                |
| Extractor | netapp (1000) | (varies)                               | Yes        | Privileged mode for GPU device access        |
| NER       | netapp (1000) | None required                          | No         | Minimal privileges                           |

#### Network Isolation

- **Internal Network**: All services communicate over the `neo-network` Docker bridge network
- **External Access**: Only the API service (port 8000) and Neo UI (port 8081) are exposed outside the Docker network — these are separate containers
- **Worker, Extractor, NER**: Not directly accessible from outside `neo-network`
- **External Dependencies**: SMB/NFS/S3 file shares; optionally Microsoft Graph API (HTTPS) and Entra ID JWKS endpoints (only when Graph or MCP OAuth is enabled)

## Security Controls Implementation

### Input Validation & Sanitization

#### API Input Validation

- **Pydantic Models**: Strict data validation for all API inputs
- **Path Traversal Protection**: Validates file paths to prevent directory traversal
- **SQL Injection Prevention**: Parameterized queries throughout database layer (56+ shared Database methods)
- **XSS Protection**: Input sanitization for user-provided content
- **MCP Content Windowing**: Configurable content window sizes (`MCP_DEFAULT_WINDOW_SIZE`, `MCP_MAX_WINDOW_SIZE`) to prevent excessive data transfer

#### File System Security

- **Path Validation**: Ensures file paths remain within configured share boundaries
- **File Type Filtering**: Configurable file type restrictions
- **Size Limits**: Configurable file size limits for content extraction

### Audit & Logging

#### Comprehensive Logging

- **Operation Logs**: All administrative and MCP operations logged with user attribution
- **Security Events**: Authentication attempts, authorization failures, OAuth token validation
- **System Events**: Crawl operations, NER analysis, Graph sync, errors, and system status
- **Structured Logging**: JSON-formatted logs suitable for SIEM integration (via Loguru)

#### Operation Types

The following operation types are tracked in the audit log:

| Category        | Operation Types                                                    |
| --------------- | ------------------------------------------------------------------ |
| Share Management| ADD_SHARE, DELETE_SHARE, UPDATE_SHARE                              |
| Crawling        | CRAWL_START, CRAWL_COMPLETE, CRAWL_ERROR                          |
| Graph Sync      | GRAPH_SYNC_START, GRAPH_SYNC_COMPLETE, GRAPH_CLEANUP               |
| MCP Access      | MCP_{TOOL_NAME} (dynamic, e.g., MCP_SEARCH_FILES, MCP_GET_FILE_CONTENT, MCP_FULL_TEXT_SEARCH, MCP_LIST_SHARES, MCP_SEARCH_ENTITIES) |
| NER             | NER_ANALYSIS (entity extraction and classification)                |
| Authentication  | USER_LOGIN                                                         |

#### Audit Trail

```python
# Example operation log structure
{
    "operation_type": "MCP_SEARCH_FILES",
    "status": "SUCCESS",
    "details": "MCP tool execution",
    "user_id": 1,
    "username": "user@contoso.com",
    "timestamp": "2026-01-15T12:00:00Z",
    "metadata": {
        "tool_name": "search_files",
        "query": "quarterly report",
        "results_count": 15
    }
}
```

### Error Handling & Information Disclosure

#### Secure Error Handling

- **Generic Error Messages**: Prevents information leakage in API responses
- **Detailed Logging**: Full error details logged internally for debugging
- **Exception Handling**: Comprehensive exception handling prevents application crashes
- **Graceful Degradation**: Continues operation when non-critical components fail (e.g., NER service unavailable does not block crawling)

## Data Privacy & Compliance

### Data Processing

#### Content Handling

- **Configurable Content Persistence**: Per-share control over content storage
- **Content Extraction**: GPU-accelerated extraction supports PDF, DOCX, PPTX, and many other formats via Docling
- **NER Processing**: Optional entity extraction identifies people, organizations, locations, and custom entity types
- **Metadata Only Mode**: Option to index only metadata without content
- **Data Retention**: Configurable retention policies for indexed content
- **Full-Text Search**: GIN-indexed search vectors for efficient content search without scanning raw data

#### Personal Data Protection

- **ACL Preservation**: Maintains original file permissions in Microsoft Graph and MCP responses
- **User Attribution**: Tracks user actions for compliance reporting
- **Data Minimization**: Only processes necessary file metadata and content
- **Right to Deletion**: Support for removing indexed content (shared `delete_share()` cleans up files, NER results, Graph items, and work queue entries)

### Compliance Features

#### Access Control Compliance

- **Permission Mapping**: Accurate translation of SMB ACLs to Graph permissions
- **MCP ACL Filtering**: Per-user search result filtering based on Entra group membership
- **Principal Resolution**: Maps on-premises identities to cloud identities
- **Audit Logging**: Comprehensive audit trail for compliance reporting
- **Data Lineage**: Tracks data from source through extraction, NER analysis, to Microsoft Graph

## Deployment Security

### Container Security

#### Base Image Security

- **Minimal Base Image**: Python 3.13-slim with only necessary packages
- **Cython Compilation**: Application code compiled to `.so` binaries (not shipped as readable Python source)
- **Regular Updates**: Base image updates for security patches
- **Vulnerability Scanning**: Container image scanning recommended
- **GPU Variants**: Separate CUDA (NVIDIA) and ROCm (AMD) images for Extractor and NER services

#### Runtime Security

- **Non-Privileged User**: Runs as `netapp` user (UID 1000) with minimal privileges
- **Read-Only Filesystem**: Application code mounted read-only
- **Resource Limits**: CPU and memory limits prevent resource exhaustion
- **Service Isolation**: Each microservice in its own container with independent resource limits

### Kubernetes Security

#### Pod Security Standards (Per-Service)

**API Service and NER Service** (minimal privileges):

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

**Worker Service** (requires SMB/NFS mount capabilities):

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  allowPrivilegeEscalation: true  # Required for SMB/NFS mounting
  capabilities:
    add: ["SYS_ADMIN", "DAC_READ_SEARCH", "DAC_OVERRIDE"]
```

**Extractor Service** (requires GPU device access):

```yaml
securityContext:
  privileged: true  # Required for GPU device access
  runAsUser: 1000
  runAsGroup: 1000
```

#### Network Policies

- **Ingress Control**: Only the API service (port 8000) and Neo UI (port 8081) should receive external traffic
- **Internal Traffic**: Worker, Extractor, and NER services accept traffic only from within `neo-network`
- **Egress Control**: Allow outbound traffic to SMB/NFS/S3 file shares and HuggingFace (model downloads); optionally Microsoft Graph and Entra ID JWKS when those integrations are enabled
- **Service Mesh**: Compatible with service mesh security policies

### Secrets Management

#### Environment Variables

```bash
# Required secrets (must be provided securely)
NETAPP_CONNECTOR_LICENSE=<license-key>

# Microsoft Graph (optional — only for M365 Copilot integration)
MS_GRAPH_CLIENT_ID=<azure-app-id>
MS_GRAPH_CLIENT_SECRET=<azure-app-secret>
MS_GRAPH_TENANT_ID=<azure-tenant-id>

# Encryption keys (auto-generated and stored in database if not set)
JWT_SECRET_KEY=<custom-jwt-secret>         # Optional: overrides database-stored key
ENCRYPTION_KEY=<base64-fernet-key>         # Optional: overrides database-stored key

# MCP OAuth (optional, for Entra ID MCP authentication)
MCP_OAUTH_ENABLED=true
MCP_OAUTH_TENANT_ID=<entra-tenant-id>
MCP_OAUTH_CLIENT_ID=<oauth-client-id>
MCP_OAUTH_CLIENT_SECRET=<oauth-client-secret>
MCP_OAUTH_AUDIENCE=<expected-audience>

# MCP API Key (optional, for CLI/automation access)
MCP_API_KEY=<static-api-key>
MCP_API_KEY_EMAIL=<identity-email>
MCP_API_KEY_NAME=<identity-display-name>

# Token configuration
ACCESS_TOKEN_EXPIRE_MINUTES=1440           # Default: 24 hours
```

#### Kubernetes Secrets

- **Secret Objects**: Store sensitive configuration in Kubernetes secrets
- **Volume Mounts**: Mount secrets as files rather than environment variables
- **RBAC**: Restrict access to secret objects
- **Database-Backed Keys**: Encryption and JWT keys stored in the `system_config` table are automatically generated if not provided via environment variables, ensuring keys persist across container restarts without requiring external secret management

## Security Best Practices

### Deployment Recommendations

1. **Network Segmentation**: Deploy in isolated network segments; only expose API (port 8000) and Neo UI (port 8081)
2. **HTTPS Termination**: Use reverse proxy/load balancer for HTTPS in front of the API service
3. **Regular Updates**: Keep base images and dependencies updated
4. **Monitoring**: Implement comprehensive monitoring and alerting across all four services
5. **Backup**: Regular backups of PostgreSQL database (contains all configuration, keys, and indexed metadata)
6. **GPU Isolation**: Run Extractor and NER services on dedicated GPU nodes with appropriate access controls

### Configuration Security

1. **Strong Passwords**: Enforce strong password policies for user accounts
2. **Token Expiration**: Configure appropriate JWT token expiration times
3. **File Filtering**: Configure file type and size restrictions
4. **Rate Limiting**: Configure MCP rate limits (`MCP_RATE_LIMIT_*` environment variables) and implement API rate limiting at proxy/gateway level
5. **Resource Limits**: Set appropriate CPU and memory limits per service
6. **ACL Mode**: Use `MCP_DEFAULT_ACL_MODE=deny` (default) to deny MCP access when user identity cannot be resolved

### Operational Security

1. **Regular Audits**: Review operation logs and user access patterns
2. **Credential Rotation**: Regular rotation of service account credentials and MCP API keys
3. **Access Reviews**: Periodic review of user accounts and permissions
4. **Incident Response**: Establish procedures for security incidents
5. **Vulnerability Management**: Regular security assessments and updates

## Security Considerations

### Known Limitations

1. **SMB Authentication**: Share passwords stored encrypted (Fernet) but accessible to the Worker service at runtime
2. **Privileged Capabilities**: Worker requires SYS_ADMIN/DAC_READ_SEARCH for SMB/NFS mounting; Extractor requires privileged mode for GPU access
3. **Content Processing**: Processes file content which may contain sensitive data (mitigated by ACL filtering)
4. **Network Access**: Requires network access to file shares; Microsoft Graph and Entra ID access only required when those integrations are enabled
5. **Internal Network Trust**: Services on `neo-network` communicate without mutual TLS (suitable for single-host Docker deployments; consider service mesh for multi-node)

### Risk Mitigation

1. **Credential Security**: Use dedicated service accounts with minimal privileges
2. **Network Security**: Deploy in secure network segments with appropriate firewalls; restrict external access to API service only
3. **Data Classification**: Implement data classification policies for indexed content
4. **Monitoring**: Continuous monitoring for unusual access patterns or errors
5. **MCP ACL Enforcement**: Enable OAuth and configure per-share ACLs for MCP access control

## Incident Response

### Security Event Types

1. **Authentication Failures**: Multiple failed login attempts, invalid OAuth tokens, rejected API keys
2. **Authorization Violations**: Access attempts to unauthorized resources, ACL denials in MCP
3. **System Errors**: Application crashes or service failures across any microservice
4. **Data Access**: Unusual file access patterns or large data transfers via MCP

### Response Procedures

1. **Log Analysis**: Review detailed logs for security events (all services log via Loguru with structured JSON)
2. **User Account Review**: Investigate suspicious user activity in operation logs
3. **System Isolation**: Ability to quickly isolate compromised services (stop individual containers)
4. **Data Impact Assessment**: Evaluate potential data exposure
5. **Recovery Procedures**: Restore from PostgreSQL backups if necessary

## Version Information

- **Document Version**: 2.0
- **Last Updated**: 2026-03-10
- **Neo Version**: 4.0.2
- **Review Date**: Annual review required

---

_This document contains confidential and proprietary information. Distribution should be limited to authorized personnel only._
