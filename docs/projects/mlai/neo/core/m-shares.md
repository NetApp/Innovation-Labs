# Share Management

Shares are the primary data sources in Project Neo. A share represents a connection to a file storage system -- an SMB file share, an NFS export, or an S3-compatible object store. Once configured, Neo crawls the share, extracts content from supported file types, and optionally uploads the results to Microsoft 365 Copilot via the Graph API.

Neo supports three storage protocols:

| Protocol | Use Case | Path Format |
|----------|----------|-------------|
| **SMB** | Windows file shares, NetApp CIFS volumes | `//server/share` |
| **NFS** | Linux/Unix exports, NetApp NFS volumes | `server:/export/path` |
| **S3** | Object storage (AWS S3, StorageGRID, MinIO) | `s3://bucket/prefix` |

All share operations require authentication. Obtain a bearer token before making API calls:

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/token \
  -d "username=admin&password=yourpassword" | jq -r .access_token)
```

Every example on this page uses this `$TOKEN` variable.

## Create a Share

```
POST /api/v1/shares
```

Creates a new share and tests connectivity before saving. If the connection test fails, the share is still created but its status is set to `connection_failed`.

Add `?crawl_immediately=true` to trigger a crawl right after creation (only if the connection test succeeds).

### SMB Share

```bash
curl -X POST "http://localhost:8000/api/v1/shares?crawl_immediately=true" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "smb",
    "share_path": "//fileserver.corp.com/documents",
    "username": "svc_neo",
    "password": "s3cur3P@ss",
    "rules": {
      "exclude_patterns": ["*.tmp", "~$*"],
      "max_file_size": 1000000000,
      "enable_copilot_upload": true
    }
  }'
```

**SMB-specific fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `share_path` | string | *(required)* | UNC path starting with `//` or `\\` |
| `username` | string | `""` | SMB username for authentication |
| `password` | string | `""` | SMB password (encrypted at rest) |
| `realm` | string | `null` | Kerberos realm (e.g., `CORP.EXAMPLE.COM`) |
| `use_kerberos` | string | `"required"` | Kerberos mode: `required`, `optional`, or `off` |
| `workgroup` | string | `null` | SMB workgroup / NT domain |
| `resolve_order` | string | `"host"` | Name resolution order |
| `smb_mount_options` | string | `null` | Additional `mount.cifs` options (e.g., `backup_intent`) |

#### SMB with Domain Authentication

```bash
curl -X POST http://localhost:8000/api/v1/shares \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "smb",
    "share_path": "//nas01.corp.example.com/finance",
    "username": "svc_neo@CORP.EXAMPLE.COM",
    "password": "s3cur3P@ss",
    "realm": "CORP.EXAMPLE.COM",
    "use_kerberos": "required",
    "workgroup": "CORP"
  }'
```

#### SMB with Backup Operators Privilege

Use the `smb_mount_options` field to pass `backup_intent`, which tells the server to grant access using Windows Backup Operators privileges. This allows the service account to read files it would not normally have permission to access:

```bash
curl -X POST http://localhost:8000/api/v1/shares \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "smb",
    "share_path": "//nas01.corp.example.com/restricted",
    "username": "svc_backup@CORP.EXAMPLE.COM",
    "password": "s3cur3P@ss",
    "smb_mount_options": "backup_intent"
  }'
```

::: tip
The service account must be a member of the Backup Operators group on the file server or in Active Directory for `backup_intent` to take effect.
:::

### NFS Share

```bash
curl -X POST "http://localhost:8000/api/v1/shares?crawl_immediately=true" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "nfs",
    "share_path": "nfs-server.corp.com:/vol/data",
    "nfs_version": "4",
    "nfs_security": "sys",
    "rules": {
      "exclude_patterns": [".snapshot/*"],
      "enable_copilot_upload": true
    }
  }'
```

**NFS-specific fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `share_path` | string | *(required)* | `server:/export/path` format |
| `nfs_version` | string | `null` (auto) | NFS protocol version: `"3"`, `"4"`, `"4.1"`, or `"4.2"` |
| `nfs_security` | string | `null` | Security flavor: `sys`, `krb5`, `krb5i`, or `krb5p` |
| `nfs_mount_options` | string | `null` | Additional NFS mount options (e.g., `nolock,soft,timeo=30`) |
| `username` | string | `""` | Not required for standard NFS |
| `password` | string | `""` | Not required for standard NFS |

#### NFS with Kerberos Security

```bash
curl -X POST http://localhost:8000/api/v1/shares \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "nfs",
    "share_path": "nfs-server.corp.com:/vol/secure",
    "nfs_version": "4.2",
    "nfs_security": "krb5p",
    "nfs_mount_options": "soft,timeo=30"
  }'
```

### S3-Compatible Object Storage

```bash
curl -X POST "http://localhost:8000/api/v1/shares?crawl_immediately=true" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "s3",
    "share_path": "s3://my-documents/reports",
    "username": "YOUR_AWS_ACCESS_KEY_HERE",
    "password": "YOUR_AWS_SECRET_KEY_HERE",
    "s3_bucket": "my-documents",
    "s3_prefix": "reports/",
    "s3_region": "us-east-1",
    "s3_use_ssl": true,
    "rules": {
      "include_patterns": ["*.pdf", "*.docx"],
      "enable_copilot_upload": true
    }
  }'
```

**S3-specific fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `s3_bucket` | string | `null` | Bucket name |
| `s3_prefix` | string | `null` | Object key prefix (acts as a directory filter) |
| `s3_endpoint_url` | string | `null` | Custom endpoint URL for StorageGRID, MinIO, etc. |
| `s3_region` | string | `null` | AWS region (e.g., `us-east-1`) |
| `s3_use_ssl` | bool | `true` | Use HTTPS for S3 connections |
| `username` | string | `""` | S3 access key ID |
| `password` | string | `""` | S3 secret access key (encrypted at rest) |

#### NetApp StorageGRID

```bash
curl -X POST http://localhost:8000/api/v1/shares \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "s3",
    "share_path": "s3://archive-bucket",
    "username": "SGRID_ACCESS_KEY",
    "password": "SGRID_SECRET_KEY",
    "s3_bucket": "archive-bucket",
    "s3_endpoint_url": "https://storagegrid.corp.com:8082",
    "s3_use_ssl": true
  }'
```

### Common Fields (All Protocols)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `protocol` | string | `"smb"` | `smb`, `nfs`, or `s3` |
| `share_path` | string | *(required)* | Connection path (format depends on protocol) |
| `crawl_schedule` | string | `"0 0 * * *"` | Cron expression for automatic crawl schedule |
| `rules` | object | *(see below)* | File filtering rules and feature toggles |

Default rules:
```json
{
  "exclude_patterns": [],
  "include_patterns": [],
  "max_file_size": 1000000000,
  "min_file_size": 0,
  "persist_file_content": true,
  "enable_copilot_upload": true
}
```

### Share Statuses

After creation, a share transitions through these statuses:

| Status | Description |
|--------|-------------|
| `initializing` | Share is being configured |
| `connecting` | Connection test in progress |
| `connected` | Connection test passed, ready to crawl |
| `connection_failed` | Connection test failed (check `error_message`) |
| `crawling` | File enumeration in progress |
| `processing` | Enumeration complete, files being extracted |
| `ready` | All work complete |
| `error` | An error occurred during processing |

## List Shares

```
GET /api/v1/shares
```

Returns all configured shares. Passwords are never included in responses.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares
```

**Response:**

```json
[
  {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "protocol": "smb",
    "share_path": "//fileserver.corp.com/documents",
    "username": "svc_neo",
    "status": "ready",
    "created_at": "2026-03-01T10:00:00",
    "last_crawled": "2026-03-10T00:00:00",
    "last_crawl_duration_ms": 45230,
    "last_crawl_file_count": 12847,
    "crawl_schedule": "0 0 * * *",
    "rules": {
      "exclude_patterns": ["*.tmp"],
      "max_file_size": 1000000000,
      "enable_copilot_upload": true
    },
    "error_message": null
  }
]
```

## Get Share Details

```
GET /api/v1/shares/{share_id}
```

Returns a single share by ID.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

Returns `404` if the share does not exist.

## Update a Share

```
PATCH /api/v1/shares/{share_id}
```

Updates share configuration. Only include the fields you want to change. Unrecognized fields are rejected.

```bash
curl -X PATCH http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "crawl_schedule": "0 */6 * * *",
    "rules": {
      "exclude_patterns": ["*.tmp", "*.bak", "~$*"],
      "max_file_size": 500000000,
      "enable_copilot_upload": true,
      "enable_ner_analysis": true,
      "ner_entity_types": ["person", "organization", "date", "money"]
    }
  }'
```

**Updatable fields:**

| Field | Description |
|-------|-------------|
| `share_path` | Update the connection path |
| `username` | Update credentials |
| `password` | Update credentials (encrypted at rest) |
| `crawl_schedule` | Cron expression for automatic crawls |
| `rules` | File filtering rules and feature toggles |
| `realm`, `use_kerberos`, `workgroup`, `resolve_order` | SMB settings |
| `nfs_version`, `nfs_security`, `nfs_mount_options` | NFS settings |
| `smb_mount_options` | SMB mount options |
| `s3_endpoint_url`, `s3_region`, `s3_bucket`, `s3_prefix`, `s3_use_ssl` | S3 settings |

### Side Effects of Rule Changes

Updating certain rules triggers automatic background actions:

- **`enable_copilot_upload` changed to `true`**: Triggers a Graph backfill -- all previously extracted files that have not been uploaded to Graph are queued for upload.
- **`enable_copilot_upload` changed to `false`**: Triggers a Graph cleanup -- all previously uploaded items are removed from Graph.
- **`enable_ner_analysis` changed to `true`**: Triggers an NER backfill -- all previously extracted files that lack NER results are queued for analysis.
- **`enable_ner_analysis` changed to `false`**: Deletes all NER results for the share and cancels pending NER work items.

For full details on rules configuration, see [Rules and Filters](m-rules-filters.md).

## Delete a Share

```
DELETE /api/v1/shares/{share_id}
```

Deletes a share and all associated data. This operation:

1. Cancels all pending work items for the share
2. Creates a cleanup work item to remove Graph entries (if Copilot upload was enabled)
3. Deletes NER results associated with the share
4. Removes the share configuration from the database

```bash
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Response:**

```json
{
  "status": "deleted",
  "share_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "work_cleared": 42
}
```

::: warning
Deletion is permanent. All extracted content, file metadata, and NER results for the share are removed. Graph cleanup happens asynchronously after the share is deleted.
:::

## Share Operations

### Trigger a Crawl

```
POST /api/v1/shares/{share_id}/crawl
```

Starts a new crawl of the share. The crawl enumerates all files, compares them against the previous inventory, and queues new or modified files for extraction.

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/crawl
```

Add `?force=true` to force a full re-crawl that ignores previously processed files:

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/crawl?force=true"
```

If a crawl is already running, the endpoint returns `already_running` without starting a duplicate:

```json
{
  "status": "already_running",
  "share_id": "a1b2c3d4-...",
  "current_status": "crawling",
  "message": "Crawl already in progress"
}
```

### Re-Extract Files with Missing Content

```
POST /api/v1/shares/{share_id}/recrawl-missing-content
```

Finds and re-queues files that were crawled but are missing extracted content. This covers two cases:

1. **Null content** -- file metadata exists but content extraction failed or produced no output. Stale metadata is deleted before re-extraction.
2. **Unextracted files** -- files stuck in `discovered` status with no metadata record at all.

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/recrawl-missing-content
```

**Response:**

```json
{
  "status": "queued",
  "share_id": "a1b2c3d4-...",
  "files_queued": 23,
  "files_found": 25,
  "null_content_files": 10,
  "unextracted_files": 15,
  "message": "Queued 23 files for re-extraction"
}
```

### Test Connection

```
POST /api/v1/shares/{share_id}/test-connection
```

Tests connectivity to an existing share without triggering a crawl. Updates the share status to `connected` or `connection_failed` based on the result.

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/test-connection
```

**Response:**

```json
{
  "share_id": "a1b2c3d4-...",
  "connection_test": {
    "success": true,
    "message": "Connection successful"
  }
}
```

### Get Crawl Progress

```
GET /api/v1/shares/{share_id}/progress
```

Returns the current crawl status, pending work items, and file inventory statistics.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/progress
```

**Response:**

```json
{
  "share_id": "a1b2c3d4-...",
  "status": "processing",
  "pending_work_items": 142,
  "file_inventory": {
    "total": 5000,
    "discovered": 142,
    "processed": 4858
  },
  "last_crawled": "2026-03-10T00:00:00",
  "last_crawl_duration_ms": 45230,
  "last_crawl_file_count": 5000
}
```

## Graph Sync Operations

These endpoints manage the Microsoft 365 Copilot integration via the Microsoft Graph External Items API. They are only relevant when `enable_copilot_upload` is `true` in the share's rules. For Graph connector setup and configuration, see [Microsoft 365 Copilot Integration](m-m365-copilot.md).

### Get Graph Sync Status

```
GET /api/v1/shares/{share_id}/graph/status
```

Returns counts of files in each Graph sync state.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/graph/status
```

**Response:**

```json
{
  "pending_upload": 50,
  "uploaded": 4800,
  "failed": 8,
  "in_progress": 2
}
```

| Field | Description |
|-------|-------------|
| `pending_upload` | Files extracted but not yet uploaded to Graph |
| `uploaded` | Files successfully uploaded |
| `failed` | Upload work items that permanently failed |
| `in_progress` | Upload work items currently being processed |

### Backfill Graph Uploads

```
POST /api/v1/shares/{share_id}/graph/backfill
```

Creates upload work items for all extracted files that have not been uploaded to Graph. Use this when:

- Graph upload was disabled during the initial crawl and has now been enabled
- You want to upload files that were skipped
- Recovering from a failed Graph connector configuration

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/graph/backfill
```

::: info
This endpoint returns `400` if `enable_copilot_upload` is `false` in the share's rules. Enable it first via [Update a Share](#update-a-share).
:::

### Cleanup Graph Uploads

```
POST /api/v1/shares/{share_id}/graph/cleanup
```

Removes all previously uploaded items from Microsoft Graph for this share. Use this when:

- Removing a share's content from Copilot search results
- Cleaning up after disabling Graph upload
- Resetting Graph state for a share before re-uploading

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/graph/cleanup
```

### Retry Failed Uploads

```
POST /api/v1/shares/{share_id}/graph/retry-failed
```

Resets all failed upload work items back to pending status, clearing their retry count so they are processed again. Use this after resolving transient issues:

- Network problems that caused temporary upload failures
- Graph API was temporarily unavailable or throttling
- Graph connector configuration issues have been fixed

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/graph/retry-failed
```

### Force Re-Upload

```
POST /api/v1/shares/{share_id}/graph/force-reupload
```

Resets all **completed** upload work items back to pending so they are re-uploaded. Use this after changing share settings that affect how items appear in Graph, such as:

- Changing `acl_override_mode` or `acl_override_principals`
- Updating the Graph connector schema
- Modifying ACL resolution behavior

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/shares/a1b2c3d4-e5f6-7890-abcd-ef1234567890/graph/force-reupload
```

::: warning
Force re-upload can generate significant Graph API traffic. For large shares, consider running this during off-peak hours.
:::

## Share Rules

Share rules control which files are crawled and how they are processed. Rules are set in the `rules` object when creating or updating a share.

**Quick example -- exclude temporary files, limit size, enable NER:**

```bash
curl -X PATCH http://localhost:8000/api/v1/shares/a1b2c3d4-... \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rules": {
      "exclude_patterns": ["*.tmp", "*.bak", "~$*", ".snapshot/*"],
      "max_file_size": 500000000,
      "modified_within_days": 90,
      "enable_copilot_upload": true,
      "enable_ner_analysis": true,
      "ner_entity_types": ["person", "organization", "location", "date", "money"],
      "ner_confidence_threshold": 0.7
    }
  }'
```

### Available Rule Fields

**File filters:**

| Field | Type | Description |
|-------|------|-------------|
| `exclude_patterns` | list | Glob patterns to exclude (e.g., `["*.tmp", "*.bak"]`) |
| `include_patterns` | list | Glob patterns to include (e.g., `["*.pdf", "*.docx"]`) |
| `max_file_size` | int | Maximum file size in bytes (default: 1,000,000,000 = 1 GB) |
| `min_file_size` | int | Minimum file size in bytes (default: 0) |

::: warning
`include_patterns` and `exclude_patterns` are mutually exclusive. You cannot set both on the same share.
:::

**Date filters (static):**

| Field | Type | Description |
|-------|------|-------------|
| `created_at_min` / `created_at_max` | ISO 8601 | File creation date range |
| `modified_time_min` / `modified_time_max` | ISO 8601 | File modification date range |
| `accessed_at_min` / `accessed_at_max` | ISO 8601 | File access date range |

**Date filters (rolling window):**

| Field | Type | Description |
|-------|------|-------------|
| `created_within_days` / `months` / `years` | int | Files created within the last N days/months/years |
| `modified_within_days` / `months` / `years` | int | Files modified within the last N days/months/years |
| `accessed_within_days` / `months` / `years` | int | Files accessed within the last N days/months/years |

::: info
You cannot combine rolling window and static date filters for the same date field. For example, setting both `modified_within_days` and `modified_time_min` will be rejected.
:::

**Feature toggles:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enable_copilot_upload` | bool | `true` | Upload extracted content to Microsoft 365 Copilot via Graph |
| `persist_file_content` | bool | `true` | Keep extracted text in the database after Graph upload |
| `enable_ner_analysis` | bool | `false` | Run Named Entity Recognition on extracted files |

**NER configuration** (when `enable_ner_analysis` is `true`):

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ner_schema` | string | `"default"` | NER schema to use |
| `ner_entity_types` | list | `["person", "organization", "location", "date", "money"]` | Entity types to extract |
| `ner_classifications` | object | `null` | Classification schemas (e.g., document type) |
| `ner_structured_extraction` | object | `null` | Structured data extraction schemas |
| `ner_confidence_threshold` | float | `0.7` | Minimum confidence for NER results (0.0-1.0) |

**ACL overrides** (for Graph upload):

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `acl_override_mode` | string | `null` | `"everyone"` = all tenant users, `"specified"` = use principal list |
| `acl_override_principals` | list | `[]` | Entra principals when mode is `"specified"` |

ACL override example:

```json
{
  "rules": {
    "acl_override_mode": "specified",
    "acl_override_principals": [
      { "type": "group", "id": "abc123-def456-..." },
      { "type": "user", "id": "xyz789-..." }
    ]
  }
}
```

For complete details on rules and filters, see [Rules and Filters](m-rules-filters.md).