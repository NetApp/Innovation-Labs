# File Management

Files in Project Neo represent the documents, spreadsheets, presentations, and other content that Neo discovers when crawling a share. Each file record stores extracted text content, metadata, and security information (ACL principals). Files are read-only from the API perspective -- they are created and updated by the worker and extractor services during crawl and extraction cycles.

All file operations require authentication. Obtain a bearer token before making API calls:

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/token \
  -d "username=admin&password=yourpassword" | jq -r .access_token)
```

Every example on this page uses this `$TOKEN` variable.

## List Files in a Share

```
GET /api/v1/shares/{share_id}/files
```

Returns a paginated list of files within a specific share, optionally filtered by directory path.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | string | `/` | Directory path to list |
| `page` | integer | `1` | Page number (starts at 1) |
| `page_size` | integer | `100` | Items per page (1--1000) |
| `fields` | string | `null` | Comma-separated field names, `*` for all, or `+field` to add to current set |
| `field_set` | string | `null` | Predefined field set: `minimal`, `standard`, `metadata`, `security`, `full` |
| `include_content` | boolean | `false` | Include extracted text content in response |

### Example

```bash
curl -s "http://localhost:8000/api/v1/shares/abc123/files?page=1&page_size=25&field_set=standard" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Response

```json
{
  "share_id": "abc123",
  "path": "/",
  "files": [
    {
      "id": "a1b2c3d4e5f6...",
      "filename": "Q4-Report.pdf",
      "size": 245760,
      "modified_time": "2026-02-15T10:30:00Z",
      "file_type": "pdf",
      "indexed_at": "2026-03-01T14:22:00Z",
      "file_path": "/finance/Q4-Report.pdf"
    }
  ],
  "total_count": 1842,
  "total_size": 4831838208,
  "page": 1,
  "page_size": 25,
  "total_pages": 74,
  "has_next": true,
  "has_previous": false
}
```

## Get File Details

```
GET /api/v1/shares/{share_id}/files/{file_id}
```

Returns full details for a specific file by ID within a share. Content is included by default.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `fields` | string | `null` | Comma-separated field names or `*` for all |
| `field_set` | string | `null` | Predefined field set name |
| `include_content` | boolean | `true` | Include extracted text content |

### Example

```bash
curl -s "http://localhost:8000/api/v1/shares/abc123/files/a1b2c3d4e5f6?field_set=metadata" \
  -H "Authorization: Bearer $TOKEN" | jq
```

## Get File by ID (Direct Lookup)

```
GET /api/v1/files/{file_id}
```

Retrieves a file by its ID without requiring the share ID. This endpoint is used by MCP tools and other integrations that only have a file ID from search results. The response includes share context fields (`share_id`, `share_name`, `share_path`) automatically.

### Example

```bash
curl -s "http://localhost:8000/api/v1/files/a1b2c3d4e5f6?field_set=standard" \
  -H "Authorization: Bearer $TOKEN" | jq
```

## Get File Metadata by Path

```
GET /api/v1/shares/{share_id}/files/metadata
```

Looks up a file by its path or ID within a share. At least one of `path` or `file_id` must be provided.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | string | `null` | File path within the share |
| `file_id` | string | `null` | File ID |
| `fields` | string | `null` | Comma-separated field names or `*` for all |
| `field_set` | string | `null` | Predefined field set name |
| `include_content` | boolean | `true` | Include extracted text content |

### Example

```bash
curl -s "http://localhost:8000/api/v1/shares/abc123/files/metadata?path=/finance/Q4-Report.pdf&field_set=security" \
  -H "Authorization: Bearer $TOKEN" | jq
```

## List All Files (Cross-Share)

```
GET /api/v1/files
```

Returns files across all shares in a single paginated response. Each file includes share context fields so you can identify which share it belongs to.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | `1` | Page number |
| `page_size` | integer | `100` | Items per page (1--1000) |
| `fields` | string | `null` | Comma-separated field names |
| `field_set` | string | `null` | Predefined field set name |
| `file_type` | string | `null` | Filter by file type (e.g., `pdf`, `docx`, `txt`) |

### Example

```bash
# List all PDF files across all shares
curl -s "http://localhost:8000/api/v1/files?file_type=pdf&page_size=50&field_set=standard" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Response

```json
{
  "files": [
    {
      "id": "a1b2c3d4e5f6...",
      "filename": "Q4-Report.pdf",
      "size": 245760,
      "modified_time": "2026-02-15T10:30:00Z",
      "file_type": "pdf",
      "indexed_at": "2026-03-01T14:22:00Z",
      "file_path": "/finance/Q4-Report.pdf",
      "share_id": "abc123",
      "share_name": "Finance Documents",
      "share_path": "//fileserver/finance"
    }
  ],
  "total_count": 5230,
  "total_size": 12884901888,
  "page": 1,
  "page_size": 50,
  "total_pages": 105,
  "has_next": true,
  "has_previous": false
}
```

## Full-Text Search

```
POST /api/v1/search
```

Searches across extracted file content using database-native full-text search. On PostgreSQL, this uses a GIN-indexed `search_vector` column that provides 20--42x faster queries compared to pattern-based search. Results include relevance scoring and content snippets.

### Request Body

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `query` | string | *(required)* | Search query in natural language (1--500 characters) |
| `share_ids` | string[] | `null` | Limit search to specific shares |
| `file_types` | string[] | `null` | Filter by file type (e.g., `["pdf", "docx"]`) |
| `modified_after` | datetime | `null` | Only files modified after this date |
| `modified_before` | datetime | `null` | Only files modified before this date |
| `page` | integer | `1` | Page number |
| `page_size` | integer | `100` | Results per page (1--1000) |
| `sort_by` | string | `relevance` | Sort field: `relevance`, `modified_time`, `filename`, `size` |
| `sort_order` | string | `desc` | Sort direction: `asc` or `desc` |
| `search_mode` | string | `natural` | MySQL only: `natural` (OR-based) or `boolean` (AND-based) |

### Example

```bash
curl -s -X POST "http://localhost:8000/api/v1/search" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "quarterly revenue forecast",
    "file_types": ["pdf", "docx", "xlsx"],
    "modified_after": "2026-01-01T00:00:00Z",
    "sort_by": "relevance",
    "page_size": 20
  }' | jq
```

### Response

```json
{
  "results": [
    {
      "id": "a1b2c3d4e5f6...",
      "share_id": "abc123",
      "filename": "Q4-Revenue-Forecast.xlsx",
      "file_path": "/finance/forecasts/Q4-Revenue-Forecast.xlsx",
      "unc_path": "//fileserver/finance/forecasts/Q4-Revenue-Forecast.xlsx",
      "size": 87040,
      "modified_time": "2026-02-28T16:45:00Z",
      "file_type": "xlsx",
      "indexed_at": "2026-03-01T14:22:00Z",
      "relevance_score": 4.82,
      "snippet": "...projected quarterly revenue of $12.4M, representing a 15% increase over...",
      "share_name": "Finance Documents",
      "resolved_principals": [
        {"display_name": "Finance Team", "type": "group", "entra_id": "..."}
      ]
    }
  ],
  "total_count": 47,
  "page": 1,
  "page_size": 20,
  "total_pages": 3,
  "has_next": true,
  "has_previous": false,
  "query": "quarterly revenue forecast",
  "search_time_ms": 23,
  "database_type": "postgresql"
}
```

::: tip Performance
The GIN-indexed `search_vector` column on PostgreSQL delivers 20--42x faster full-text search compared to `LIKE`/`ILIKE` pattern matching. No additional configuration is required -- the index is created automatically during database initialization.
:::

## Field Selection

Every file endpoint supports field selection to control response payload size. There are three ways to specify which fields to return.

### Predefined Field Sets

Use the `field_set` query parameter to select a named set of fields:

| Field Set | Fields Included |
|-----------|----------------|
| `minimal` | `id`, `filename`, `size` |
| `standard` | `id`, `filename`, `size`, `modified_time`, `file_type`, `indexed_at`, `file_path` |
| `metadata` | All metadata fields: timestamps, file type, extractor info, directory flag |
| `security` | `id`, `filename`, `file_path`, `acl_principals`, `resolved_principals` |
| `full` | All fields including `content` and `content_chunks` |

For cross-share endpoints (`GET /api/v1/files`, `GET /api/v1/files/{file_id}`), each field set automatically includes `share_id`, `share_name`, and `share_path`.

### Custom Field Lists

Use the `fields` query parameter with a comma-separated list:

```bash
# Only return specific fields
curl -s "http://localhost:8000/api/v1/files?fields=id,filename,size,file_type" \
  -H "Authorization: Bearer $TOKEN"
```

### Additive Fields

Prefix field names with `+` to add them to the current field set:

```bash
# Start with standard set, add security fields
curl -s "http://localhost:8000/api/v1/files?field_set=standard&fields=+acl_principals,+resolved_principals" \
  -H "Authorization: Bearer $TOKEN"
```

Use `fields=*` to request all available fields.

## File Metadata Fields

The complete set of fields available for each file:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Deterministic SHA-256 hash of the normalized UNC path (32 hex characters) |
| `share_id` | string | ID of the parent share |
| `file_path` | string | Relative path within the share |
| `unc_path` | string | Full UNC path to the file (e.g., `//server/share/path/file.pdf`) |
| `filename` | string | File name including extension |
| `size` | integer | File size in bytes |
| `created_at` | datetime | File creation timestamp |
| `modified_time` | datetime | Last modification timestamp |
| `accessed_at` | datetime | Last access timestamp |
| `is_directory` | boolean | `true` if this entry is a directory |
| `file_type` | string | File extension without dot (e.g., `pdf`, `docx`) |
| `content` | string | Extracted text content (main chunk) |
| `content_chunks` | string[] | Deprecated -- chunks are now stored as separate database rows |
| `chunk_count` | integer | Number of content chunk rows for large files |
| `total_content_size` | integer | Total extracted content size in bytes |
| `conversion_duration_ms` | integer | Time spent extracting content (milliseconds) |
| `extractor_used` | string | Extraction method: `markitdown`, `docling_fallback`, `direct_read`, etc. |
| `indexed_at` | datetime | Timestamp when the file was last indexed |
| `protocol` | string | Source protocol: `smb`, `nfs`, or `s3` |
| `acl_principals` | string[] | Raw ACL principal names and SIDs from the file system |
| `acl_details` | object | Full ACL structure with SIDs, display names, and permission masks |
| `resolved_principals` | object[] | ACL principals resolved against Microsoft Entra ID |
| `share_name` | string | Parent share name (cross-share endpoints only) |
| `share_path` | string | Parent share path (cross-share endpoints only) |

## File Processing Lifecycle

When Neo crawls a share, each file moves through a processing pipeline managed by the work queue:

```
pending --> processing --> completed
               |
               +--> error (retried up to max_retries)
```

1. **Pending** -- The file has been discovered during a share crawl and queued for content extraction.
2. **Processing** -- A worker has claimed the file and the extractor service is converting it to text.
3. **Completed** -- Content extraction succeeded. The file's `content` field is populated and the `search_vector` index is updated.
4. **Error** -- Extraction failed. The work queue retries the file automatically (default: up to 3 retries). Persistent failures are logged with an error message.

Once a file reaches the **completed** state, it is available for full-text search and its metadata is visible in all listing endpoints.

## Content Chunking

Large files are split into multiple content chunks stored as separate rows in the database. The main file record has `is_chunk = false` and `chunk_index = 0`. Additional chunks have `is_chunk = true` and incrementing `chunk_index` values. The `chunk_count` field on the main record indicates how many chunk rows exist. This single-table design enables full-text search across all content without expensive `UNION` queries.
