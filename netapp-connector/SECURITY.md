# NetApp Copilot Connector - Security Documentation

## Overview

The NetApp Copilot Connector is a secure enterprise application that enables Microsoft 365 Copilot to access and index content from NetApp file shares. This document provides comprehensive security information for security teams evaluating the connector's architecture, implementation, and security controls.

## Application Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐
│   Microsoft     │    │   Microsoft      │
│   365 Copilot   │◄──►│   Graph API      │
│                 │    │                  │
└─────────────────┘    └──────────────────┘
                              ▲
                              │
                              ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │    NetApp        │    │   NetApp File   │
                       │   Connector      │◄──►│   Shares (SMB)  │
                       │                  │    │                 │
                       └──────────────────┘    └─────────────────┘
```

### Core Components

1. **FastAPI Web Application**: RESTful API server handling authentication, share management, and file operations
2. **Share Crawler**: Background service that discovers and indexes files from SMB shares
3. **Microsoft Graph Connector**: Uploads indexed content to Microsoft Graph for Copilot integration
4. **Database Layer**: SQL-based storage for metadata, user accounts, and operational logs
5. **Security Manager**: Centralized security services for authentication, encryption, and access control

## Security Architecture

### Authentication & Authorization

#### JWT-Based Authentication

- **Algorithm**: HS256 (HMAC with SHA-256)
- **Token Expiration**: Configurable (default: 24 hours)
- **Secret Key Management**:
  - Auto-generated 256-bit secret key stored in `data/jwt_secret.key`
  - Persistent across application restarts
  - Fallback mechanism for file system issues

#### User Management

- **Password Hashing**: bcrypt with 12 rounds (configurable)
- **User Roles**: Standard users and administrators
- **Account Management**: Create, authenticate, and manage user accounts
- **Session Management**: JWT tokens with configurable expiration

#### API Security

- **OAuth2 Bearer Token**: Standard OAuth2 implementation
- **Protected Endpoints**: All administrative and data access endpoints require authentication
- **Role-Based Access**: Admin-only endpoints for user management and system configuration

### Data Encryption

#### At-Rest Encryption

- **Database**: Database files stored with filesystem-level encryption support
- **Credential Storage**: SMB passwords encrypted using Fernet (AES 128 in CBC mode)
- **Key Management**:
  - Fernet encryption keys auto-generated and stored in `data/key.key`
  - Keys are 256-bit URL-safe base64-encoded
  - Secure key generation using `cryptography` library

#### In-Transit Encryption

- **HTTPS**: Application designed to run behind HTTPS proxy/load balancer
- **Microsoft Graph API**: All communications over HTTPS
- **SMB Connections**: Supports SMB encryption when available on target shares

### Access Control & Permissions

#### SMB Share Access

- **Authentication**: Username/password or Kerberos authentication
- **ACL Processing**: Extracts and processes Windows ACLs from SMB shares
- **Principal Resolution**: Maps SMB principals to Microsoft Entra (Azure AD) objects
- **Permission Inheritance**: Respects Windows file system permissions

#### Microsoft Graph Integration

- **Service Principal Authentication**: Uses Azure AD application credentials
- **Scoped Permissions**: Requires specific Graph API permissions for connector operations
- **ACL Mapping**: Translates SMB ACLs to Microsoft Graph external item permissions

### Network Security

#### Container Security

- **Non-Root Execution**: Runs as dedicated `netapp` user (UID 1000)
- **Minimal Privileges**: Only necessary system capabilities enabled
- **Isolated Environment**: Containerized deployment with resource constraints

#### Kubernetes Security Context

```yaml
securityContext:
  capabilities:
    add: ["SYS_ADMIN", "DAC_READ_SEARCH", "DAC_OVERRIDE"]
  allowPrivilegeEscalation: true
  runAsUser: 1000
  runAsGroup: 1000
```

#### Network Isolation

- **Internal Communication**: Database and file system access within container
- **External Dependencies**: Microsoft Graph API (HTTPS), SMB shares (SMB/CIFS)
- **Port Exposure**: Single HTTP port (8080) for API access

## Security Controls Implementation

### Input Validation & Sanitization

#### API Input Validation

- **Pydantic Models**: Strict data validation for all API inputs
- **Path Traversal Protection**: Validates file paths to prevent directory traversal
- **SQL Injection Prevention**: Parameterized queries throughout database layer
- **XSS Protection**: Input sanitization for user-provided content

#### File System Security

- **Path Validation**: Ensures file paths remain within configured share boundaries
- **File Type Filtering**: Configurable file type restrictions
- **Size Limits**: Configurable file size limits for content extraction

### Audit & Logging

#### Comprehensive Logging

- **Operation Logs**: All administrative operations logged with user attribution
- **Security Events**: Authentication attempts, authorization failures
- **System Events**: Crawl operations, errors, and system status
- **Structured Logging**: JSON-formatted logs suitable for SIEM integration

#### Audit Trail

```python
# Example operation log structure
{
    "operation_type": "ADD_SHARE",
    "status": "SUCCESS",
    "details": "Share configuration added",
    "user_id": 1,
    "username": "admin",
    "timestamp": "2024-01-01T12:00:00Z",
    "metadata": {
        "share_path": "\\\\server\\share",
        "config_changes": {...}
    }
}
```

### Error Handling & Information Disclosure

#### Secure Error Handling

- **Generic Error Messages**: Prevents information leakage in API responses
- **Detailed Logging**: Full error details logged internally for debugging
- **Exception Handling**: Comprehensive exception handling prevents application crashes
- **Graceful Degradation**: Continues operation when non-critical components fail

## Data Privacy & Compliance

### Data Processing

#### Content Handling

- **Configurable Content Persistence**: Per-share control over content storage
- **Content Extraction**: Supports multiple file formats with configurable limits
- **Metadata Only Mode**: Option to index only metadata without content
- **Data Retention**: Configurable retention policies for indexed content

#### Personal Data Protection

- **ACL Preservation**: Maintains original file permissions in Microsoft Graph
- **User Attribution**: Tracks user actions for compliance reporting
- **Data Minimization**: Only processes necessary file metadata and content
- **Right to Deletion**: Support for removing indexed content

### Compliance Features

#### Access Control Compliance

- **Permission Mapping**: Accurate translation of SMB ACLs to Graph permissions
- **Principal Resolution**: Maps on-premises identities to cloud identities
- **Audit Logging**: Comprehensive audit trail for compliance reporting
- **Data Lineage**: Tracks data from source to Microsoft Graph

## Deployment Security

### Container Security

#### Base Image Security

- **Minimal Base Image**: Python 3.13-slim with only necessary packages
- **Regular Updates**: Base image updates for security patches
- **Vulnerability Scanning**: Container image scanning recommended

#### Runtime Security

- **Non-Privileged User**: Runs as non-root user with minimal privileges
- **Read-Only Filesystem**: Application code mounted read-only
- **Resource Limits**: CPU and memory limits prevent resource exhaustion

### Kubernetes Security

#### Pod Security Standards

```yaml
# Security context configuration
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  allowPrivilegeEscalation: true # Required for SMB mounting
  capabilities:
    add: ["SYS_ADMIN", "DAC_READ_SEARCH", "DAC_OVERRIDE"]
```

#### Network Policies

- **Ingress Control**: Restrict inbound traffic to necessary ports
- **Egress Control**: Allow outbound traffic to Microsoft Graph and SMB shares only
- **Service Mesh**: Compatible with service mesh security policies

### Secrets Management

#### Environment Variables

```bash
# Required secrets (must be provided securely)
NETAPP_CONNECTOR_LICENSE=<license-key>
MS_GRAPH_CLIENT_ID=<azure-app-id>
MS_GRAPH_CLIENT_SECRET=<azure-app-secret>
MS_GRAPH_TENANT_ID=<azure-tenant-id>

# Optional security configuration
ACCESS_TOKEN_EXPIRE_MINUTES=1440
JWT_SECRET_KEY=<custom-jwt-secret>
```

#### Kubernetes Secrets

- **Secret Objects**: Store sensitive configuration in Kubernetes secrets
- **Volume Mounts**: Mount secrets as files rather than environment variables
- **RBAC**: Restrict access to secret objects

## Security Best Practices

### Deployment Recommendations

1. **Network Segmentation**: Deploy in isolated network segments
2. **HTTPS Termination**: Use reverse proxy/load balancer for HTTPS
3. **Regular Updates**: Keep base images and dependencies updated
4. **Monitoring**: Implement comprehensive monitoring and alerting
5. **Backup**: Regular backups of database and configuration

### Configuration Security

1. **Strong Passwords**: Enforce strong password policies for user accounts
2. **Token Expiration**: Configure appropriate JWT token expiration times
3. **File Filtering**: Configure file type and size restrictions
4. **Rate Limiting**: Implement API rate limiting at proxy/gateway level
5. **Resource Limits**: Set appropriate CPU and memory limits

### Operational Security

1. **Regular Audits**: Review operation logs and user access patterns
2. **Credential Rotation**: Regular rotation of service account credentials
3. **Access Reviews**: Periodic review of user accounts and permissions
4. **Incident Response**: Establish procedures for security incidents
5. **Vulnerability Management**: Regular security assessments and updates

## Security Considerations

### Known Limitations

1. **SMB Authentication**: Passwords stored encrypted but accessible to application
2. **Privileged Capabilities**: Requires elevated capabilities for SMB mounting
3. **Content Processing**: Processes file content which may contain sensitive data
4. **Network Access**: Requires network access to both SMB shares and Microsoft Graph

### Risk Mitigation

1. **Credential Security**: Use dedicated service accounts with minimal privileges
2. **Network Security**: Deploy in secure network segments with appropriate firewalls
3. **Data Classification**: Implement data classification policies for indexed content
4. **Monitoring**: Continuous monitoring for unusual access patterns or errors

## Incident Response

### Security Event Types

1. **Authentication Failures**: Multiple failed login attempts
2. **Authorization Violations**: Access attempts to unauthorized resources
3. **System Errors**: Application crashes or service failures
4. **Data Access**: Unusual file access patterns or large data transfers

### Response Procedures

1. **Log Analysis**: Review detailed logs for security events
2. **User Account Review**: Investigate suspicious user activity
3. **System Isolation**: Ability to quickly isolate compromised systems
4. **Data Impact Assessment**: Evaluate potential data exposure
5. **Recovery Procedures**: Restore from backups if necessary

## Version Information

- **Document Version**: 1.0
- **Last Updated**: 2025-07-25
- **Connector Version**: 2.1.0
- **Review Date**: Annual review required

---

_This document contains confidential and proprietary information. Distribution should be limited to authorized personnel only._
