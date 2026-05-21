# Virtual Datasets

Virtual Datasets are curated, shareable collections of indexed files that can span multiple shares and storage protocols. They allow users to group files from across SMB, NFS, and S3 sources into a single searchable collection, share it with colleagues or Entra ID groups, and control access independently of the underlying file-level permissions.

> [!IMPORTANT]
> Virtual Datasets require PostgreSQL. Deployments using MySQL will receive an HTTP 501 response for all dataset endpoints.

All dataset operations require authentication. Obtain a bearer token before making API calls:

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/token \
  -d "username=admin&password=yourpassword" | jq -r .access_token)
```

Every example on this page uses this `$TOKEN` variable.

---

## Key Capabilities

| Capability | Description |
|------------|-------------|
| **Multi-protocol** | A single dataset can contain files from SMB, NFS, and S3 shares |
| **Collaboration** | Share datasets with local users, Entra ID users, or Entra ID groups |
| **Granular permissions** | READ, WRITE, ADMIN, and OWNER permission levels |
| **Scoped search** | Full-text and named entity search within a dataset |
| **ACL override** | Optionally bypass file-level ACLs so shared users can see all items |
| **Auto-expiration** | Datasets expire after a configurable period (default 90 days) |
| **Subset creation** | Create new datasets from filtered subsets of existing ones |
| **Audit logging** | All operations are recorded for compliance and monitoring |
| **Rate limiting** | Per-user rate limits protect system resources |

---

## Permission Model

Access to a dataset is determined by a four-level permission hierarchy:

| Level | Capabilities |
|-------|-------------|
| **READ** | View dataset metadata, list items, search within the dataset |
| **WRITE** | Everything in READ, plus add and remove items |
| **ADMIN** | Everything in WRITE, plus share with others and update dataset settings |
| **OWNER** | Full control including deletion (assigned to the dataset creator) |

When a user matches multiple shares (for example, via both a direct share and a group share), the highest permission applies.

**Public datasets** grant READ access to all authenticated users without requiring an explicit share.

---

## Creating a Dataset

```
POST /api/v1/datasets
```

Creates a new dataset from a list of file IDs. File IDs are typically obtained from a [search](m-search) or [file listing](m-files) operation.

### Request

```bash
curl -X POST http://localhost:8000/api/v1/datasets \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Q4 Financial Reports",
    "description": "All Q4 reports across regional shares",
    "file_ids": ["a1b2c3...", "d4e5f6...", "g7h8i9..."],
    "is_public": false,
    "acl_override_enabled": false,
    "expires_at": "2026-09-01T00:00:00Z"
  }'
```

### Parameters

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | *(required)* | Dataset name (1--255 characters) |
| `description` | string | `null` | Optional description |
| `file_ids` | array | *(required)* | One or more file IDs to include |
| `source_query` | object | `null` | Optional metadata about the original search query |
| `is_public` | boolean | `false` | Make visible to all authenticated users |
| `acl_override_enabled` | boolean | `false` | Bypass file-level ACLs for shared users |
| `expires_at` | datetime | 90 days from now | Expiration date (configurable via `DATASET_DEFAULT_EXPIRATION_DAYS`) |

### Response (201 Created)

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "name": "Q4 Financial Reports",
  "description": "All Q4 reports across regional shares",
  "owner_id": 1,
  "owner_username": "admin",
  "is_public": false,
  "acl_override_enabled": false,
  "item_count": 3,
  "created_at": "2026-05-21T10:00:00Z",
  "updated_at": "2026-05-21T10:00:00Z",
  "expires_at": "2026-09-01T00:00:00Z",
  "expires_in_hours": 2424.0,
  "source_query": null,
  "user_permission": "owner",
  "metadata": null
}
```

> [!NOTE]
> File IDs are validated before creation. Invalid IDs are skipped, and the dataset is created with the valid files. If no valid file IDs are provided, the request returns 400.

---

## Listing Datasets

```
GET /api/v1/datasets
```

Returns a paginated list of datasets the current user can access.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | `1` | Page number |
| `page_size` | integer | `20` | Items per page (1--100) |
| `owned_only` | boolean | `false` | Show only datasets you own |

### Example

```bash
curl -s "http://localhost:8000/api/v1/datasets?page=1&page_size=10" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Response (200 OK)

```json
{
  "datasets": [ ... ],
  "total_count": 42,
  "page": 1,
  "page_size": 10,
  "total_pages": 5,
  "has_next": true,
  "has_previous": false
}
```

Admin users see all datasets by default. Use `owned_only=true` to filter to only your own.

---

## Get Dataset Details

```
GET /api/v1/datasets/{dataset_id}
```

Returns full details for a specific dataset. Requires at least READ permission.

```bash
curl -s "http://localhost:8000/api/v1/datasets/f47ac10b-58cc-4372-a567-0e02b2c3d479" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## Update a Dataset

```
PATCH /api/v1/datasets/{dataset_id}
```

Updates dataset metadata. Requires ADMIN permission or ownership.

```bash
curl -X PATCH "http://localhost:8000/api/v1/datasets/f47ac10b-58cc-4372-a567-0e02b2c3d479" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Q4 Financial Reports (Updated)",
    "is_public": true,
    "expires_at": "2026-12-31T23:59:59Z"
  }'
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | New name (1--255 characters) |
| `description` | string | New description |
| `is_public` | boolean | Change visibility |
| `acl_override_enabled` | boolean | Change ACL override setting |
| `expires_at` | datetime | Change expiration date |

All fields are optional. At least one must be provided.

---

## Delete a Dataset

```
DELETE /api/v1/datasets/{dataset_id}
```

Permanently deletes a dataset and all its items and shares. Only the dataset owner can delete it.

```bash
curl -X DELETE "http://localhost:8000/api/v1/datasets/f47ac10b-58cc-4372-a567-0e02b2c3d479" \
  -H "Authorization: Bearer $TOKEN"
```

Returns 204 No Content on success.

---

## Managing Items

### Add Files to a Dataset

```
POST /api/v1/datasets/{dataset_id}/items
```

Adds files to an existing dataset. Requires WRITE permission.

```bash
curl -X POST "http://localhost:8000/api/v1/datasets/f47ac10b.../items" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "file_ids": ["x1y2z3...", "a4b5c6..."],
    "notes": "Added from latest crawl"
  }'
```

**Response (200 OK):**

```json
{
  "added": 2,
  "dataset_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479"
}
```

### List Items in a Dataset

```
GET /api/v1/datasets/{dataset_id}/items
```

Returns a paginated list of files in the dataset. Requires READ permission.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | `1` | Page number |
| `page_size` | integer | `100` | Items per page (1--1000) |

```bash
curl -s "http://localhost:8000/api/v1/datasets/f47ac10b.../items?page=1&page_size=50" \
  -H "Authorization: Bearer $TOKEN" | jq
```

Each item includes the file's name, path, UNC path, share, size, type, modification time, and when it was added to the dataset.

> [!NOTE]
> Unless ACL override is enabled, file-level access controls are enforced -- users only see items they have permission to access on the underlying share.

### Remove Files from a Dataset

```
DELETE /api/v1/datasets/{dataset_id}/items
```

Removes files from a dataset. Requires WRITE permission. The files themselves are not deleted from the share.

```bash
curl -X DELETE "http://localhost:8000/api/v1/datasets/f47ac10b.../items" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"file_ids": ["x1y2z3..."]}'
```

---

## Searching Within a Dataset

### Full-Text Search

```
POST /api/v1/datasets/{dataset_id}/search
```

Searches the extracted content of files within a dataset. Requires READ permission.

```bash
curl -X POST "http://localhost:8000/api/v1/datasets/f47ac10b.../search" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "revenue forecast Q4",
    "file_types": ["pdf", "xlsx"],
    "sort_by": "relevance",
    "page_size": 25
  }'
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `query` | string | *(required)* | Search query (1--500 characters). Supports AND, OR, NOT operators and quoted phrases |
| `file_types` | array | `null` | Filter by file extension (e.g., `["pdf", "docx"]`) |
| `page` | integer | `1` | Page number |
| `page_size` | integer | `100` | Items per page (1--1000) |
| `sort_by` | string | `"relevance"` | Sort by: `relevance`, `modified_time`, `filename`, or `size` |
| `sort_order` | string | `"desc"` | Sort direction: `asc` or `desc` |

**Response** includes relevance scores, content snippets with highlighted matches, and full file metadata.

### Named Entity Search

```
POST /api/v1/datasets/{dataset_id}/ner-search
```

Searches for named entities (people, organizations, locations, etc.) identified by the [NER service](m-ner) within a dataset. Requires READ permission.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `q` | string | *(required)* | Entity search term |
| `entity_type` | string | `null` | Filter by entity type (e.g., `PERSON`, `ORG`) |
| `match_mode` | string | `"substring"` | Match mode: `substring`, `exact`, or `prefix` |
| `limit` | integer | `20` | Results per page (1--200) |
| `cursor` | string | `null` | Pagination cursor from previous response |

```bash
curl -X POST "http://localhost:8000/api/v1/datasets/f47ac10b.../ner-search?q=NetApp&entity_type=ORG&match_mode=prefix" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Creating Subsets

```
POST /api/v1/datasets/{dataset_id}/subset
```

Creates a new dataset from a filtered subset of an existing one. Requires READ permission on the source dataset.

```bash
curl -X POST "http://localhost:8000/api/v1/datasets/f47ac10b.../subset" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Q4 PDFs Only",
    "description": "PDF subset of Q4 reports",
    "file_ids": ["a1b2c3...", "d4e5f6..."]
  }'
```

The file IDs must belong to the source dataset. The new dataset is owned by the calling user with its own expiration and sharing settings.

---

## Sharing Datasets

### Share with a User or Group

```
POST /api/v1/datasets/{dataset_id}/shares
```

Shares a dataset with a local user, Entra ID user, or Entra ID group. Requires ADMIN permission or ownership.

```bash
curl -X POST "http://localhost:8000/api/v1/datasets/f47ac10b.../shares" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "analyst01",
    "permission": "read",
    "expires_at": "2026-08-01T00:00:00Z"
  }'
```

Exactly one share target must be specified:

| Target | Description |
|--------|-------------|
| `user_id` | Local user ID |
| `username` | Local username (resolved to user ID) |
| `entra_user_id` | Microsoft Entra user object ID |
| `entra_group_id` | Microsoft Entra group object ID |

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `permission` | string | `"read"` | Permission level: `read`, `write`, or `admin` |
| `expires_at` | datetime | `null` | Optional share expiration |

#### Share with an Entra ID Group

```bash
curl -X POST "http://localhost:8000/api/v1/datasets/f47ac10b.../shares" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entra_group_id": "12345678-abcd-1234-abcd-123456789012",
    "permission": "write"
  }'
```

### List Shares

```
GET /api/v1/datasets/{dataset_id}/shares
```

Returns all active shares for a dataset. Requires ADMIN permission or ownership.

```bash
curl -s "http://localhost:8000/api/v1/datasets/f47ac10b.../shares" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Update a Share

```
PATCH /api/v1/datasets/{dataset_id}/shares/{share_id}
```

Updates the permission level or expiration of a share. Requires ADMIN permission or ownership.

```bash
curl -X PATCH "http://localhost:8000/api/v1/datasets/f47ac10b.../shares/abc123..." \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"permission": "admin"}'
```

### Revoke a Share

```
DELETE /api/v1/datasets/{dataset_id}/shares/{share_id}
```

Revokes access for a specific share. Returns 204 No Content.

```bash
curl -X DELETE "http://localhost:8000/api/v1/datasets/f47ac10b.../shares/abc123..." \
  -H "Authorization: Bearer $TOKEN"
```

---

## ACL Override

By default, when users list or search items in a dataset, file-level access controls from the underlying storage are enforced. Users only see files they have permission to access on the original share.

When **ACL override** is enabled on a dataset, shared users can access all items regardless of file-level permissions. This is useful when you want to share a curated collection without requiring users to have direct access to the underlying shares.

> [!WARNING]
> Enabling ACL override grants access to file content that users may not have permission to view at the storage level. All override access is recorded in the audit log for compliance review.

**Enable ACL override on creation:**

```bash
curl -X POST http://localhost:8000/api/v1/datasets \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Cross-Team Research",
    "file_ids": ["..."],
    "acl_override_enabled": true
  }'
```

**Enable ACL override on an existing dataset:**

```bash
curl -X PATCH "http://localhost:8000/api/v1/datasets/f47ac10b..." \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"acl_override_enabled": true}'
```

---

## Expiration

Datasets expire automatically to prevent stale data collections from accumulating.

| Setting | Default | Description |
|---------|---------|-------------|
| Default expiration | 90 days | Applied when `expires_at` is not specified |
| Custom expiration | -- | Set via `expires_at` on create or update |
| Countdown warnings | 10 days before | Logged daily, then hourly on the final day |
| Auto-deletion | On expiry | Dataset, items, and shares are automatically removed |

The default expiration period is configurable via the `DATASET_DEFAULT_EXPIRATION_DAYS` environment variable.

### Monitoring Expiring Datasets

Administrators can query for datasets nearing expiration:

```bash
curl -s "http://localhost:8000/api/v1/datasets/expiring?within_hours=240" \
  -H "Authorization: Bearer $TOKEN" | jq
```

This returns all datasets expiring within the specified window (default 240 hours / 10 days). Requires admin access.

---

## Rate Limiting

Dataset operations are rate-limited per user to protect system resources:

| Operation | Default Limit | Environment Variable |
|-----------|--------------|---------------------|
| Create / subset | 10 per minute | `DATASET_RATE_LIMIT_CREATE` |
| Search (text and NER) | 20 per minute | `DATASET_RATE_LIMIT_SEARCH` |
| Item operations (add/remove/list) | 30 per minute | `DATASET_RATE_LIMIT_ITEMS` |

When a rate limit is exceeded, the API returns HTTP 429 with a `Retry-After` header.

---

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `DATASET_DEFAULT_EXPIRATION_DAYS` | `90` | Default dataset lifetime in days |
| `DATASET_RATE_LIMIT_CREATE` | `10` | Max create operations per user per minute |
| `DATASET_RATE_LIMIT_SEARCH` | `20` | Max search operations per user per minute |
| `DATASET_RATE_LIMIT_ITEMS` | `30` | Max item operations per user per minute |

---

## API Reference

| Method | Endpoint | Description | Permission |
|--------|----------|-------------|------------|
| `POST` | `/api/v1/datasets` | Create a dataset | Authenticated |
| `GET` | `/api/v1/datasets` | List accessible datasets | Authenticated |
| `GET` | `/api/v1/datasets/expiring` | List expiring datasets | Admin |
| `GET` | `/api/v1/datasets/{id}` | Get dataset details | READ |
| `PATCH` | `/api/v1/datasets/{id}` | Update dataset metadata | ADMIN / Owner |
| `DELETE` | `/api/v1/datasets/{id}` | Delete dataset | Owner |
| `POST` | `/api/v1/datasets/{id}/items` | Add files to dataset | WRITE |
| `GET` | `/api/v1/datasets/{id}/items` | List files in dataset | READ |
| `DELETE` | `/api/v1/datasets/{id}/items` | Remove files from dataset | WRITE |
| `POST` | `/api/v1/datasets/{id}/search` | Full-text search within dataset | READ |
| `POST` | `/api/v1/datasets/{id}/ner-search` | Named entity search within dataset | READ |
| `POST` | `/api/v1/datasets/{id}/subset` | Create a subset dataset | READ |
| `POST` | `/api/v1/datasets/{id}/shares` | Share dataset | ADMIN / Owner |
| `GET` | `/api/v1/datasets/{id}/shares` | List shares | ADMIN / Owner |
| `PATCH` | `/api/v1/datasets/{id}/shares/{share_id}` | Update share | ADMIN / Owner |
| `DELETE` | `/api/v1/datasets/{id}/shares/{share_id}` | Revoke share | ADMIN / Owner |

---

## Error Responses

| Status | Meaning |
|--------|---------|
| 400 | Invalid request (no valid file IDs, missing required fields, validation errors) |
| 401 | Authentication required |
| 403 | Insufficient permission |
| 404 | Dataset or share not found |
| 429 | Rate limit exceeded (check `Retry-After` header) |
| 501 | PostgreSQL required (MySQL not supported) |
