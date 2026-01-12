# MCP (Model Context Protocol) User Guide

This guide explains how to configure and use the Model Context Protocol (MCP) integration with the NetApp Connector, enabling AI assistants like ChatGPT Enterprise and Anthropic Claude to search and retrieve files from your file shares with proper access control.

---

## Table of Contents

1.  [Overview](#overview)
2.  [Architecture](#architecture)
3.  [Prerequisites](#prerequisites)
4.  [Configuration](#configuration)
5.  [Claude Desktop Setup](#claude-desktop-setup)
6.  [Available Tools](#available-tools)
7.  [Security & Access Control](#security--access-control)
8.  [Rate Limiting](#rate-limiting)
9.  [Troubleshooting](#troubleshooting)
10. [Environment Variables Reference](#environment-variables-reference)

---

## Overview

The MCP integration allows AI assistants to securely search and retrieve content from your NetApp file shares. Key features include:

- **🔐 ACL-Based Access Control**: Users can only access files they have permission to view based on SMB ACLs resolved to Microsoft Entra IDs
- **🔍 Full-Text Search**: Search file content using natural language queries
- **📄 Content Windowing**: Navigate large documents in chunks that fit AI context windows
- **⚡ Rate Limiting**: Per-user rate limits prevent abuse and ensure fair usage
- **🔒 OAuth 2.0 Authentication**: Secure authentication via Microsoft Entra ID

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         User asks Claude a question                         │
│                    "Find the Q4 financial reports"                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Claude Desktop                                 │
│                     Uses MCP tools to search files                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ MCP Protocol (HTTP + OAuth)
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         NetApp Connector MCP Server                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   OAuth     │  │ ACL Filter  │  │ Rate Limiter│  │ Content Windowing   │ │
│  │ Validation  │  │ (per-user)  │  │ (per-user)  │  │ (large documents)   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ Internal API calls
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         NetApp Connector Database                           │
│              (File metadata, content, ACLs, search indexes)                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Architecture

### Component Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              AI AGENT LAYER                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                  │
│  │ Claude Desktop │  │  Windsurf IDE  │  │  Custom Agent  │                  │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘                  │
│          │                   │                   │                           │
│          └───────────────────┼───────────────────┘                           │
│                              │                                               │
└──────────────────────────────┼───────────────────────────────────────────────┘
                               │ MCP Protocol
                               │ (HTTP POST /mcp)
                               ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                           MCP SERVER LAYER                                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    HTTP Transport (FastAPI Router)                      │ │
│  │                         POST /mcp endpoint                              │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│         ┌──────────────────────────┼──────────────────────────┐              │
│         ▼                          ▼                          ▼              │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐         │
│  │   OAuth     │           │ ACL Filter  │           │    Rate     │         │
│  │ Validation  │           │             │           │   Limiter   │         │
│  │             │           │ - User ID   │           │             │         │
│  │ - Entra ID  │           │ - Groups    │           │ - Per-tool  │         │
│  │ - JWT       │           │ - Share ACL │           │ - Per-user  │         │
│  │ - Groups    │           │   Override  │           │ - Bytes     │         │
│  └─────────────┘           └─────────────┘           └─────────────┘         │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           MCP TOOLS                                     │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │ │
│  │  │ search_files │ │ full_text_   │ │ get_file_    │ │ list_shares  │    │ │
│  │  │              │ │ search       │ │ content      │ │              │    │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘    │ │
│  │  ┌──────────────┐                                                       │ │
│  │  │ search_      │                                                       │ │
│  │  │ entities     │                                                       │ │
│  │  └──────────────┘                                                       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                               │
                               │ Internal HTTP
                               ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                        NETAPP CONNECTOR API                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ GET /files  │  │ POST /search│  │ GET /shares │  │ GET /ner/entities   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow for File Access

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FILE ACCESS FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

  User Request                    MCP Server                    Response
       │                              │                             │
       │  1. "Get quarterly report"   │                             │
       ├─────────────────────────────►│                             │
       │                              │                             │
       │                    ┌─────────┴─────────┐                   │
       │                    │ 2. Validate OAuth │                   │
       │                    │    Bearer Token   │                   │
       │                    └─────────┬─────────┘                   │
       │                              │                             │
       │                    ┌─────────┴─────────┐                   │
       │                    │ 3. Extract User   │                   │
       │                    │    Object ID &    │                   │
       │                    │    Group Members  │                   │
       │                    └─────────┬─────────┘                   │
       │                              │                             │
       │                    ┌─────────┴─────────┐                   │
       │                    │ 4. Search Files   │                   │
       │                    │    in Database    │                   │
       │                    └─────────┬─────────┘                   │
       │                              │                             │
       │                    ┌─────────┴─────────┐                   │
       │                    │ 5. ACL Filter:    │                   │
       │                    │    Check each file│                   │
       │                    │    resolved_      │                   │
       │                    │    principals     │                   │
       │                    └─────────┬─────────┘                   │
       │                              │                             │
       │                    ┌─────────┴─────────┐                   │
       │                    │ 6. Return only    │                   │
       │                    │    accessible     │                   │
       │                    │    files          │                   │
       │                    └─────────┬─────────┘                   │
       │                              │                             │
       │◄─────────────────────────────┤                             │
       │  7. Filtered results         │                             │
```

---

## Prerequisites

Before configuring MCP, ensure you have:

1.  **NetApp Connector Running**: The connector API must be accessible (default: `http://localhost:8080`)
2.  **Microsoft Entra ID App Registration**: Required for OAuth authentication
3.  **Indexed File Shares**: At least one share must be configured and crawled
4.  **ACL Resolution Enabled**: Files should have `resolved_principals` for proper access control

### Microsoft Entra ID Requirements

Your Entra ID app registration needs:

| Permission  | Type      | Purpose                   |
| ----------- | --------- | ------------------------- |
| `User.Read` | Delegated | Read user profile         |
| `openid`    | Delegated | OpenID Connect sign-in    |
| `profile`   | Delegated | Read user's basic profile |
| `email`     | Delegated | Read user's email address |

---

## Configuration

### Step 1: Configure Environment Variables

Add these to your `.env` file or container environment:

```bash
# OAuth Configuration (Required for MCP)
MCP_OAUTH_ENABLED=true
MCP_OAUTH_TENANT_ID=your-tenant-id          # Microsoft Entra tenant ID
MCP_OAUTH_CLIENT_ID=your-client-id          # App registration client ID
MCP_OAUTH_CLIENT_SECRET=your-client-secret  # App registration secret

# Optional: Rate Limiting Configuration
MCP_RATE_LIMIT_SEARCH=30        # search_files requests per minute
MCP_RATE_LIMIT_FULL_TEXT=20     # full_text_search requests per minute
MCP_RATE_LIMIT_CONTENT=60       # get_file_content requests per minute
MCP_RATE_LIMIT_SHARES=10        # list_shares requests per minute
MCP_RATE_LIMIT_ENTITIES=20      # search_entities requests per minute
MCP_RATE_LIMIT_TOTAL=100        # Total requests per minute per user
MCP_RATE_LIMIT_BYTES=10485760   # Content bytes per minute (10MB)

# Optional: Content Windowing
MCP_DEFAULT_WINDOW_SIZE=50000   # Default content window (50KB)
MCP_MAX_WINDOW_SIZE=100000      # Maximum content window (100KB)

# Optional: Default ACL Mode (when no resolved_principals)
MCP_DEFAULT_ACL_MODE=deny       # "deny" (secure) or "allow"
```

### Step 2: Verify MCP Endpoint

Once configured, verify the MCP endpoint is available:

```bash
# Check OAuth metadata endpoint
curl http://localhost:8080/.well-known/oauth-protected-resource

# Expected response:
{
  "resource": "http://localhost:8080/mcp",
  "authorization_servers": ["http://localhost:8080"],
  "scopes_supported": ["openid", "profile", "email", "offline_access"],
  "bearer_methods_supported": ["header"]
}
```

---

## Claude Desktop Setup

### Option A: HTTP Transport with Automatic OAuth (Recommended)

This method allows Claude Desktop to handle OAuth automatically. Edit your Claude Desktop configuration file:

**Location:**

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/claude/claude_desktop_config.json`

**Configuration:**

```json
{
  "mcpServers": {
    "netapp-files": {
      "url": "http://localhost:8080/mcp",
      "oauth": {
        "client_id": "your-client-id",
        "client_secret": "your-client-secret",
        "authorization_url": "http://localhost:8080/authorize",
        "token_url": "http://localhost:8080/token",
        "scopes": ["openid", "profile", "email"]
      }
    }
  }
}
```

**How it works:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AUTOMATIC OAUTH FLOW                                     │
└─────────────────────────────────────────────────────────────────────────────┘

  Claude Desktop              NetApp Connector              Microsoft Entra
       │                            │                             │
       │  1. First MCP request      │                             │
       ├───────────────────────────►│                             │
       │                            │                             │
       │  2. 401 + WWW-Authenticate │                             │
       │◄───────────────────────────┤                             │
       │                            │                             │
       │  3. Open browser for login │                             │
       ├────────────────────────────┼────────────────────────────►│
       │                            │                             │
       │                            │  4. User signs in           │
       │                            │◄────────────────────────────┤
       │                            │                             │
       │  5. Receive auth code      │                             │
       │◄───────────────────────────┼─────────────────────────────┤
       │                            │                             │
       │  6. Exchange for token     │                             │
       ├───────────────────────────►│                             │
       │                            │                             │
       │  7. Access token           │                             │
       │◄───────────────────────────┤                             │
       │                            │                             │
       │  8. MCP request + Bearer   │                             │
       ├───────────────────────────►│                             │
       │                            │                             │
       │  9. Results (ACL filtered) │                             │
       │◄───────────────────────────┤                             │
```

### Option B: stdio Transport with Manual Token

For development or when HTTP transport isn't available:

```json
{
  "mcpServers": {
    "netapp-files": {
      "command": "python",
      "args": ["-m", "app.mcp"],
      "cwd": "/path/to/netapp-copilot-connector-gen-2",
      "env": {
        "NETAPP_API_URL": "http://localhost:8080",
        "MCP_OAUTH_ENABLED": "true",
        "MCP_OAUTH_TENANT_ID": "your-tenant-id",
        "MCP_OAUTH_CLIENT_ID": "your-client-id",
        "MCP_OAUTH_CLIENT_SECRET": "your-client-secret",
        "MCP_OAUTH_TOKEN": "your-user-oauth-token"
      }
    }
  }
}
```

**Note:** With Option B, you must manually obtain and update the OAuth token.

### Getting a Manual OAuth Token

If using stdio transport, obtain a token using one of these methods:

#### Method 1: Browser Login

1.  Visit `http://localhost:8080/auth/login`
2.  Sign in with your Microsoft account
3.  Copy the access token from the success page

#### Method 2: Device Code Flow

```bash
# 1. Initiate device code flow
curl -X POST "http://localhost:8080/auth/device"

# Response:
# {
#   "user_code": "ABCD1234",
#   "verification_uri": "https://microsoft.com/devicelogin",
#   "device_code": "..."
# }

# 2. Visit the URL and enter the code

# 3. Poll for the token
curl -X POST "http://localhost:8080/auth/device/poll?device_code=YOUR_DEVICE_CODE"
```

#### Method 3: Azure CLI

```bash
az login
az account get-access-token --resource api://your-client-id --query accessToken -o tsv
```

---

## Available Tools

The MCP server exposes five tools for AI agents:

### 1\. `search_files`

Search for files by name, type, date, or size across all accessible shares.

**Parameters:**

| Parameter         | Type    | Description                                      |
| ----------------- | ------- | ------------------------------------------------ |
| `query`           | string  | Text to search in filename (case-insensitive)    |
| `file_type`       | string  | Filter by extension: `pdf`, `docx`, `xlsx`, etc. |
| `path`            | string  | Filter by path pattern (e.g., `/reports/`)       |
| `modified_after`  | string  | ISO datetime - files modified after this date    |
| `modified_before` | string  | ISO datetime - files modified before this date   |
| `size_min`        | integer | Minimum file size in bytes                       |
| `size_max`        | integer | Maximum file size in bytes                       |
| `limit`           | integer | Max results (default: 20, max: 100)              |

**Example Usage:**

```
"Find all PDF files modified in the last month"
→ search_files(file_type="pdf", modified_after="2024-11-01")
```

### 2\. `full_text_search`

Search file content using natural language queries with boolean operators.

**Parameters:**

| Parameter    | Type    | Description                                        |
| ------------ | ------- | -------------------------------------------------- |
| `query`      | string  | **Required.** Search query with optional operators |
| `file_types` | array   | Filter by file types: `["pdf", "docx"]`            |
| `limit`      | integer | Max results (default: 20, max: 100)                |

**Query Syntax:**

- Simple: `quarterly report`
- AND: `budget AND 2024`
- OR: `invoice OR receipt`
- Phrase: `"project alpha"`
- Exclude: `report -draft`

**Example Usage:**

```
"Search for documents mentioning Project Alpha"
→ full_text_search(query="\"Project Alpha\"")
```

### 3\. `get_file_content`

Retrieve extracted text content from a file with windowing for large documents.

**Parameters:**

| Parameter          | Type    | Description                                        |
| ------------------ | ------- | -------------------------------------------------- |
| `file_id`          | string  | **Required.** File ID from search results          |
| `share_id`         | string  | Share ID (optional, improves performance)          |
| `window_start`     | integer | Character offset to start from (default: 0)        |
| `window_size`      | integer | Characters to return (default: 50000, max: 100000) |
| `include_metadata` | boolean | Include file metadata (default: true)              |

**Response includes navigation hints:**

```json
{
  "file_id": "abc123",
  "filename": "annual_report.pdf",
  "content": "... extracted text ...",
  "window": {
    "start": 0,
    "size": 50000,
    "total_length": 250000,
    "has_more": true,
    "next_start": 50000,
    "progress_percent": 20
  }
}
```

**Scrolling through large documents:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONTENT WINDOWING                                        │
└─────────────────────────────────────────────────────────────────────────────┘

  Document (250KB total)
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                                                                         │
  │  Window 1: 0-50KB        Window 2: 50-100KB      Window 3: 100-150KB    │
  │  ┌──────────────┐        ┌──────────────┐        ┌──────────────┐       │
  │  │ Introduction │   →    │ Chapter 1    │   →    │ Chapter 2    │  ...  │
  │  │ Executive    │        │ Analysis     │        │ Results      │       │
  │  │ Summary      │        │              │        │              │       │
  │  └──────────────┘        └──────────────┘        └──────────────┘       │
  │                                                                         │
  └─────────────────────────────────────────────────────────────────────────┘

  Request 1: get_file_content(file_id="abc", window_start=0)
  Request 2: get_file_content(file_id="abc", window_start=50000)
  Request 3: get_file_content(file_id="abc", window_start=100000)
```

### 4\. `list_shares`

List available file shares in the system.

**Parameters:** None

**Response:**

```json
{
  "shares": [
    {
      "id": "share-uuid",
      "name": "Finance",
      "path": "\\\\server\\finance",
      "status": "READY",
      "file_count": 1250
    }
  ]
}
```

### 5\. `search_entities`

Find files containing specific named entities (people, organizations, etc.) extracted via NER.

**Parameters:**

| Parameter      | Type    | Description                                                                          |
| -------------- | ------- | ------------------------------------------------------------------------------------ |
| `entity_value` | string  | **Required.** Entity to search for                                                   |
| `entity_type`  | string  | Type filter: `person`, `organization`, `location`, `date`, `money`, `email`, `phone` |
| `limit`        | integer | Max results (default: 20, max: 100)                                                  |

**Example Usage:**

```
"Find documents mentioning Acme Corporation"
→ search_entities(entity_value="Acme Corporation", entity_type="organization")
```

---

## Security & Access Control

### ACL Filtering Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ACL ACCESS DECISION FLOW                            │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │  File Request   │
                              └────────┬────────┘
                                       │
                                       ▼
                         ┌─────────────────────────┐
                         │ File has resolved_      │
                         │ principals?             │
                         └────────────┬────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │ YES                               │ NO
                    ▼                                   ▼
         ┌─────────────────────┐           ┌─────────────────────┐
         │ User Object ID in   │           │ Share has           │
         │ resolved_principals?│           │ acl_override_mode?  │
         └──────────┬──────────┘           └──────────┬──────────┘
                    │                                  │
         ┌──────────┴──────────┐           ┌──────────┴──────────┐
         │ YES          │ NO   │           │ YES          │ NO   │
         ▼              ▼      │           ▼              ▼
    ┌────────┐   ┌───────────┐ │    ┌───────────┐   ┌────────┐
    │ ALLOW  │   │ User in   │ │    │ Check     │   │ DENY   │
    │        │   │ group in  │ │    │ override  │   │        │
    └────────┘   │ resolved_ │ │    │ rules     │   └────────┘
                 │ principals│ │    └─────┬─────┘
                 └─────┬─────┘ │          │
                       │       │   ┌──────┴──────┐
              ┌────────┴───────┐   │             │
              │ YES      │ NO  │   ▼             ▼
              ▼          ▼     │  "everyone"   "specified"
         ┌────────┐  ┌────────┐│  ┌────────┐   ┌───────────┐
         │ ALLOW  │  │ DENY   ││  │ ALLOW  │   │ User in   │
         └────────┘  └────────┘│  └────────┘   │ specified │
                               │               │ principals│
                               │               └─────┬─────┘
                               │                     │
                               │              ┌──────┴──────┐
                               │              │ YES    │ NO │
                               │              ▼        ▼
                               │         ┌────────┐ ┌────────┐
                               │         │ ALLOW  │ │ DENY   │
                               │         └────────┘ └────────┘
```

### Share-Level ACL Override

When files don't have resolved ACL principals, you can configure share-level fallback:

```json
{
  "rules": {
    "acl_override_mode": "everyone"
  }
}
```

**Options:**

- `"everyone"` - All authenticated users can access files without resolved ACLs
- `"specified"` - Only specified users/groups can access:

```json
{
  "rules": {
    "acl_override_mode": "specified",
    "acl_override_principals": [
      { "type": "group", "id": "group-object-id" },
      { "type": "user", "id": "user-object-id" }
    ]
  }
}
```

### Security Best Practices

1.  **Keep `MCP_DEFAULT_ACL_MODE=deny`** - This ensures files without resolved ACLs are not accessible
2.  **Use HTTPS in production** - Configure SSL/TLS for the connector API
3.  **Rotate client secrets regularly** - Update your Entra ID app registration secrets
4.  **Monitor MCP operations** - All MCP tool calls are logged to the operations log
5.  **Configure appropriate rate limits** - Prevent abuse with per-user limits

---

## Rate Limiting

Rate limits protect the system from abuse and ensure fair usage across users.

### Default Limits (per minute per user)

| Limit Type         | Default | Environment Variable       |
| ------------------ | ------- | -------------------------- |
| `search_files`     | 30      | `MCP_RATE_LIMIT_SEARCH`    |
| `full_text_search` | 20      | `MCP_RATE_LIMIT_FULL_TEXT` |
| `get_file_content` | 60      | `MCP_RATE_LIMIT_CONTENT`   |
| `list_shares`      | 10      | `MCP_RATE_LIMIT_SHARES`    |
| `search_entities`  | 20      | `MCP_RATE_LIMIT_ENTITIES`  |
| Total requests     | 100     | `MCP_RATE_LIMIT_TOTAL`     |
| Content bytes      | 10MB    | `MCP_RATE_LIMIT_BYTES`     |

### Rate Limit Response

When rate limited, tools return:

```json
{
  "error": "rate_limited",
  "message": "Rate limit exceeded for search_files",
  "retry_after": 45,
  "rate_limit": {
    "allowed": false,
    "remaining": 0,
    "limit": 30,
    "reset_at": 1702732800.0
  }
}
```

---

## Troubleshooting

### Common Issues

#### 1\. "OAuth provider not configured"

**Cause:** Missing OAuth environment variables

**Solution:** Ensure these are set:

```bash
MCP_OAUTH_ENABLED=true
MCP_OAUTH_TENANT_ID=your-tenant-id
MCP_OAUTH_CLIENT_ID=your-client-id
MCP_OAUTH_CLIENT_SECRET=your-client-secret
```

#### 2\. "Token validation failed"

**Cause:** Invalid or expired OAuth token

**Solutions:**

- Refresh your OAuth token
- Check that the token audience matches your app registration
- Verify the token hasn't expired

#### 3\. "Access denied" for files you should have access to

**Cause:** ACL resolution issues

**Solutions:**

- Verify the file has `resolved_principals` in the database
- Check that your Entra Object ID matches a principal
- Verify your group memberships are being fetched correctly
- Consider configuring `acl_override_mode` on the share

#### 4\. "Rate limit exceeded"

**Cause:** Too many requests in a short period

**Solutions:**

- Wait for the `retry_after` period
- Reduce request frequency
- Increase rate limits via environment variables

#### 5\. Files not appearing in search results

**Causes:**

- Files haven't been crawled yet
- Files don't match your ACL permissions
- Search filters are too restrictive

**Solutions:**

- Verify the share has been crawled (check share status)
- Check file ACLs and your permissions
- Broaden search parameters

### Viewing MCP Logs

MCP operations are logged to the connector's operations log:

```bash
# View recent MCP operations
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8080/operations?operation_type=MCP_SEARCH_FILES&limit=10"
```

Log entries include:

- Tool name and arguments
- User identity (Object ID, email)
- Operation status (SUCCESS/ERROR)
- Result counts

---

## Environment Variables Reference

### OAuth Configuration

| Variable                  | Required | Default | Description                             |
| ------------------------- | -------- | ------- | --------------------------------------- |
| `MCP_OAUTH_ENABLED`       | Yes      | `false` | Enable OAuth authentication             |
| `MCP_OAUTH_TENANT_ID`     | Yes      | \-      | Microsoft Entra tenant ID               |
| `MCP_OAUTH_CLIENT_ID`     | Yes      | \-      | App registration client ID              |
| `MCP_OAUTH_CLIENT_SECRET` | Yes      | \-      | App registration client secret          |
| `MCP_OAUTH_TOKEN`         | No       | \-      | Pre-configured OAuth token (stdio mode) |

### Rate Limiting

| Variable                   | Required | Default    | Description                   |
| -------------------------- | -------- | ---------- | ----------------------------- |
| `MCP_RATE_LIMIT_SEARCH`    | No       | `30`       | search_files requests/min     |
| `MCP_RATE_LIMIT_FULL_TEXT` | No       | `20`       | full_text_search requests/min |
| `MCP_RATE_LIMIT_CONTENT`   | No       | `60`       | get_file_content requests/min |
| `MCP_RATE_LIMIT_SHARES`    | No       | `10`       | list_shares requests/min      |
| `MCP_RATE_LIMIT_ENTITIES`  | No       | `20`       | search_entities requests/min  |
| `MCP_RATE_LIMIT_TOTAL`     | No       | `100`      | Total requests/min per user   |
| `MCP_RATE_LIMIT_BYTES`     | No       | `10485760` | Content bytes/min (10MB)      |

### Content Windowing

| Variable                  | Required | Default  | Description                 |
| ------------------------- | -------- | -------- | --------------------------- |
| `MCP_DEFAULT_WINDOW_SIZE` | No       | `50000`  | Default window size (chars) |
| `MCP_MAX_WINDOW_SIZE`     | No       | `100000` | Maximum window size (chars) |

### Access Control

| Variable               | Required | Default | Description                                  |
| ---------------------- | -------- | ------- | -------------------------------------------- |
| `MCP_DEFAULT_ACL_MODE` | No       | `deny`  | Default ACL mode when no resolved_principals |

### Server Configuration

| Variable         | Required | Default                 | Description              |
| ---------------- | -------- | ----------------------- | ------------------------ |
| `NETAPP_API_URL` | No       | `http://localhost:8080` | NetApp Connector API URL |
| `MCP_LOG_LEVEL`  | No       | `INFO`                  | Logging level            |

---

## Additional Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [Microsoft Entra ID Documentation](https://learn.microsoft.com/en-us/entra/identity/)
- [ChatGPT Enterprise Developer Mode Guide](https://platform.openai.com/docs/guides/developer-mode)
- [Claude Desktop MCP Guide](https://docs.anthropic.com/claude/docs/mcp)
- [NetApp Connector API Documentation](/docs)

---

_Last updated: January 2026_
