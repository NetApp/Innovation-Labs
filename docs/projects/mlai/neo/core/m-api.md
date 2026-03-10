# NetApp NEO User API Guide

The API documentation is available at ```http://localhost:8000/docs``` after starting the connector.

> ![NOTE]
> The connector will generate a secure random admin password for you by default, be sure to retrieve this from the logs.
> You can also retrieve the initial credentials programmatically via `GET /api/v1/setup/initial-credentials`.

Learn how to create a new administrator user for accessing and managing your NetApp shares.
 
### Postman Collection

For your convenience, a Postman collection for the NetApp Connector API is available [here](/projects/mlai/neo/examples/NetAppConnectorforM365Copilot.postman_collection.json).

Once you have the collection, you can import it into Postman and start using it to interact with the API. For ease of use, the postman collection uses postman environments to store the variables required to interact with the API. You will need to set the following variables in the postman environment:

- ```HOST``` - The hostname/IP of the connector (e.g., ```http://localhost```)
- ```PORT``` - The port on which the connector is running (e.g., ```8080```)
- ```SMB_HOST``` - The hostname/IP of the SMB server (e.g., ```10.0.0.9```)
- ```SMB_USER``` - The username for the SMB server (e.g., ```admin```)
- ```SMB_PASSWORD``` - The password for the SMB server (e.g., `password`)

#### Authenticate the user

Send a POST request to ```/token``` with the following payload:

Request Body:

```json
{
  "username": "admin",
  "password": "your_password"
}
```

Response:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer"
}
```

Use the ```access_token``` to authenticate your requests to the API. The postman collection is configured to automatically use the token for subsequent requests.

## 3. Adding Your First Share

Discover how to connect the connector to your NetApp share, enabling file access.

Now that you have an admin user, you can add your first share. Send a POST request to ```/shares``` with the following payload:

Request Body:

```json
{
  "share_path": "\\\\server\\share",
  "username": "domain\\user",
  "password": "share_password",
  "crawl_schedule": "0 0 * * *",
  "rules": {
    "exclude_patterns": [".git/*", "*.tmp"],
    "max_file_size": 1000000000,
    "min_file_size": 0,
    "min_modified_time": "2025-01-01T00:00:00",
    "max_modified_time": null,
    "min_accessed_time": null,
    "max_accessed_time": null,
    "min_created_time": null,
    "max_created_time": "2025-03-01T00:00:00"
  }
}
```

**_Note_** for details on the rules and filters, see the [Rules and Filters](/projects/mlai/neo/core/m-rules-filters.md) section below.

Response: Updated ShareResponse object

This will add a new share to the connector and start crawling the share according to the specified schedule. The crawl_schedule is a cron expression that determines how often the share will be crawled. The rules object allows you to filter files based on various criteria.

Here are some examples of the cron expression to help get your started:

Once a day at midnight:

```
0 0 * * *
```

Every 15 minutes:

```
*/15 * * * *
```

Every hour:

```
0 * * * *
```

Every 5 minutes on weekdays:

```
*/5 * * * 1-5
```

You can use [CronTab Guru](https://crontab.guru/) to generate cron expressions.

## 4. Rules and Filters

Explore the powerful rules and filters available to control access and manage your files.

#### File Filtering Rules

The connector supports filtering files based on patterns. These are configured at the share level:

- ```exclude_patterns```: Exclude files matching these patterns (e.g., ```["*.tmp", ".git/*"]```)

#### Timestamp Filtering Rules

The connector supports filtering files based on timestamps:

- ```min_modified_time```: Only include files modified on or after this time (ISO 8601 format, e.g., "2025-01-01T00:00:00")
- ```max_modified_time```: Only include files modified on or before this time
- ```min_accessed_time```: Only include files accessed on or after this time
- ```max_accessed_time```: Only include files accessed on or before this time
- ```min_created_time```: Only include files created on or after this time
- ```max_created_time```: Only include files created on or before this time

Setting any of these values to ```null``` (or omitting them) disables that specific filter.

#### File Size Filtering Rules

The connector supports filtering files based on size:

- ```min_file_size```: Only include files larger than this size (in bytes)
- ```max_file_size```: Only include files smaller than this size (in bytes)

## 5. Monitoring Operations

Understand how to monitor the connector's operations and troubleshoot any issues.

#### GET /api/v1/monitoring/operations

Get operation logs with optional filtering.

Query Parameters:

- ```limit``` (optional): Maximum number of logs to return (default: 100)
- ```type``` (optional): Filter by operation type (e.g., "LIST_FILES", "GET_SHARE")
- ```action``` (optional): Filter by action (metadata)
- ```status``` (optional): Filter by status (e.g., "SUCCESS", "ERROR")
- ```share_id``` (optional): Filter by share ID (metadata)
- ```since``` (optional): Limit to operations since this ISO timestamp

Response:

```json
[
  {
    "id": 1,
    "operation_type": "LIST_FILES",
    "status": "SUCCESS",
    "details": "Listed files in share: 6852076d-f1cb-4843-807c-ddfe54d83a71",
    "timestamp": "2025-01-30T13:08:32.990378",
    "metadata": {},
    "user_id": 1,
    "username": "admin"
  }
]
```

### Health Check

#### GET /health

Check the health status of the service.

Response:

```json
{
  "status": "healthy",
  "service": "api",
  "version": "4.0.2",
  "timestamp": "2026-03-10T12:00:00+00:00"
}
```

#### GET /health/detailed

Detailed health check with component status.

Response:

```json
{
  "status": "healthy",
  "service": "api",
  "version": "4.0.2",
  "components": {
    "database": "ok",
    "oauth": "configured"
  },
  "worker_url": "http://worker-service:8001",
  "timestamp": "2026-03-10T12:00:00+00:00"
}
```

## 6. BONUS: Querying Files

The NetApp Connector API provides a powerful search capability to query files based on various criteria. You can search for files based on their metadata, and more in future.

To list all files for a given share, send a GET request to ```/shares/{share_id}/files```.

Response:

```json
{
  "share_id": "6852076d-f1cb-4843-807c-ddfe54d83a71",
  "path": "/documents",
  "files": [
    {
      "id": "c0b92459-3ec3-41ea-b95a-5abd54b31ca5",
      "file_path": "documents/Example.docx",
      "filename": "Example.docx",
      "size": 13301,
      "created_at": "2025-01-21T15:10:58.756600",
      "modified_time": "2025-01-21T15:10:58.756600",
      "accessed_at": "2025-01-30T11:06:44.754267",
      "is_directory": false,
      "file_type": "docx",
      "indexed_at": "2025-01-30T13:08:32.990378"
    }
  ],
  "total_count": 1,
  "total_size": 13301,
  "page": 1,
  "page_size": 100,
  "total_pages": 1,
  "has_next": false,
  "has_previous": false
}
```

Go ahead and start exploring the API to see what else you can do!

---

## API Endpoint Reference

This section provides a complete overview of all endpoint groups available in the NetApp Project Neo v4 API.

### Auth

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| POST | `/token` | Authenticate and obtain a JWT access token |
| POST | `/logout` | Invalidate the current session |

### Setup (29 endpoints)

Configuration and initial setup wizard. See the [Configuration Guide](./d-configuration.md) for full details.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/api/v1/setup/status` | Get current setup status |
| POST | `/api/v1/setup/complete` | Mark setup as complete |
| POST | `/api/v1/setup/license` | Configure license |
| GET | `/api/v1/setup/license/status` | Get license status |
| POST | `/api/v1/setup/graph` | Configure Microsoft Graph |
| GET | `/api/v1/setup/graph` | Get Graph settings |
| GET | `/api/v1/setup/graph/connections` | List Graph connections |
| GET | `/api/v1/setup/graph/connections/{id}` | Get a specific Graph connection |
| POST | `/api/v1/setup/mcp` | Configure MCP OAuth |
| GET | `/api/v1/setup/mcp` | Get MCP OAuth settings |
| POST | `/api/v1/setup/mcp/api-key` | Create or regenerate MCP API key |
| GET | `/api/v1/setup/mcp/api-key` | Get MCP API key status |
| DELETE | `/api/v1/setup/mcp/api-key` | Revoke MCP API key |
| POST | `/api/v1/setup/ssl` | Configure SSL/TLS |
| GET | `/api/v1/setup/ssl` | Get SSL settings |
| POST | `/api/v1/setup/proxy` | Configure HTTP proxy |
| GET | `/api/v1/setup/proxy` | Get proxy settings |
| POST | `/api/v1/setup/reload` | Reload configuration |
| POST | `/api/v1/setup/reset` | Reset setup state |
| GET | `/api/v1/setup/extractors` | List extractor configurations |
| POST | `/api/v1/setup/extractors` | Configure extractors |
| DELETE | `/api/v1/setup/extractors` | Remove extractor configuration |
| POST | `/api/v1/setup/factory-reset` | Factory reset the connector |
| GET | `/api/v1/setup/initial-credentials` | Retrieve initial admin credentials |

### Shares

CRUD operations, crawl control, and Microsoft Graph sync. See the [Shares Guide](./m-shares.md) for full details.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/api/v1/shares` | List all shares |
| POST | `/api/v1/shares` | Create a new share |
| GET | `/api/v1/shares/{share_id}` | Get share details |
| PATCH | `/api/v1/shares/{share_id}` | Update share settings |
| DELETE | `/api/v1/shares/{share_id}` | Delete a share |
| POST | `/api/v1/shares/{share_id}/crawl` | Trigger a crawl |
| POST | `/api/v1/shares/{share_id}/graph-sync` | Trigger Graph sync |

### Files

File listing, retrieval, and search. See the [Files Guide](./m-files.md) for full details.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/api/v1/shares/{share_id}/files` | List files in a share |
| GET | `/api/v1/files/{file_id}` | Get file metadata |
| POST | `/api/v1/files/search` | Search files by content or metadata |

### Users

User management (CRUD). See the [Users Guide](./m-users.md) for full details.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/api/v1/users` | List users |
| POST | `/api/v1/users` | Create a user |
| GET | `/api/v1/users/{user_id}` | Get user details |
| PATCH | `/api/v1/users/{user_id}` | Update a user |
| DELETE | `/api/v1/users/{user_id}` | Delete a user |

### NER (Named Entity Recognition)

Entity results, statistics, schemas, and settings. See the [NER Guide](./m-ner.md) when available.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/api/v1/ner/entities` | Get NER results |
| GET | `/api/v1/ner/stats` | Get NER statistics |
| GET | `/api/v1/ner/schemas` | List NER schemas |
| GET | `/api/v1/ner/settings` | Get NER settings |
| PATCH | `/api/v1/ner/settings` | Update NER settings |

### Monitoring

System monitoring, work queue, worker status, benchmarking, and tuning.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/api/v1/monitoring/overview` | Comprehensive monitoring overview |
| GET | `/api/v1/monitoring/work-queue` | Work queue statistics |
| GET | `/api/v1/monitoring/work-queue/by-share/{share_id}` | Work queue stats for a share |
| GET | `/api/v1/monitoring/workers` | Active worker statistics |
| GET | `/api/v1/monitoring/services` | Service health status |
| GET | `/api/v1/monitoring/failed-items` | Failed work items |
| POST | `/api/v1/monitoring/retry-failed` | Retry failed items |
| GET | `/api/v1/monitoring/operations` | Operation logs |
| GET | `/api/v1/monitoring/database/size` | Database size and statistics |
| GET | `/api/v1/monitoring/enumeration` | Enumeration stats (proxied to worker) |
| GET | `/api/v1/monitoring/graph-rate-limit` | Graph API rate limit stats |
| GET | `/api/v1/monitoring/sizing/profiles` | Sizing profiles |
| GET | `/api/v1/monitoring/sizing/current` | Current sizing vs. recommended |
| GET | `/api/v1/monitoring/sizing/parameters` | Tunable parameters |
| POST | `/api/v1/monitoring/benchmark/run` | Start a benchmark run |
| GET | `/api/v1/monitoring/benchmark/status` | Benchmark progress |
| GET | `/api/v1/monitoring/benchmark/results` | Latest benchmark results |
| GET | `/api/v1/monitoring/benchmark/history` | Historical benchmark results |
| GET | `/api/v1/monitoring/tuning/recommendations` | Auto-tuner recommendations |
| GET | `/api/v1/monitoring/tuning/history` | Tuning change history |
| POST | `/api/v1/monitoring/tuning/apply` | Apply a tuning recommendation |
| POST | `/api/v1/monitoring/tuning/rollback` | Revert last tuning change |
| GET | `/api/v1/monitoring/tuning/status` | Auto-tuner status |
| POST | `/api/v1/monitoring/work-items/retry` | Retry specific work items |

### Tasks

Background task management.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/api/v1/tasks` | List background tasks |
| GET | `/api/v1/tasks/{task_id}` | Get task status |
| GET | `/api/v1/tasks/{task_id}/detailed` | Get detailed task info |
| DELETE | `/api/v1/tasks/{task_id}` | Cancel a running task |
| GET | `/api/v1/tasks/statistics/summary` | Task statistics summary |
| GET | `/api/v1/tasks/statistics/acl-cache` | ACL cache statistics |

### Health

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/health` | Basic health check |
| GET | `/health/detailed` | Detailed health with component status |
| GET | `/ready` | Kubernetes readiness probe |
| GET | `/version` | Version information |

### MCP (Model Context Protocol)

AI agent integration endpoint. See the [MCP Guide](./m-mcp.md) for full details.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| POST | `/mcp` | MCP Streamable HTTP transport |
