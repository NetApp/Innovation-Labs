# NetApp Connector User Quick Start Guide

This guide assumes that you have deployed the NetApp connector and are ready to start using it. If you have not yet deployed the connector, please refer to the [NetApp Connector README](README.md).

## 1. Getting Started

The easiest way to get started is by using the pre-built Docker image:

```bash
docker pull ghcr.io/netapp/netapp-copilot-connector:latest
```

or for a specific version:

```bash
docker pull ghcr.io/netapp/netapp-copilot-connector:2.0.1
```

Or you can import the tar file from the offline distribution package:

```bash
docker load -i netapp-connector.tar
```

### Running the Container

1. Download the [Sample .env file](./dist/.env.example) and rename it to `.env`.
2. Configure the `.env` file with the required environment variables. The following environment variables are required:

````bash
# NetApp Settings
NETAPP_CONNECTOR_LICENSE=your-licence-key-here # Mandatory

# Microsoft Graph configuration
MS_GRAPH_CLIENT_ID=your-client-id-here # Mandatory
MS_GRAPH_CLIENT_SECRET=your-client-secret-here # Mandatory
MS_GRAPH_TENANT_ID=your-tenant-id-here # Mandatory```
````

3. Download the latest docker-compose file from the [dist](./dist) directory.
4. Run the following docker-compose command to deploy the connector:

```bash
docker-compose up -d
```

### Using Helm

If you are using Kubernetes, you can deploy the connector using Helm. Please refer to the [Helm Deployment](helm/README.md) document for more information.

## 2. Using the API and creating an admin user

Learn how to create a new administrator user for accessing and managing your NetApp shares.

### Postman Collection

For your convenience, a Postman collection for the NetApp Connector API is available [here](https://github.com/NetApp/Innovation-Labs/blob/main/netapp-connector/postman/NetAppConnectorforM365Copilot.postman_collection.json).

Once you have the collection, you can import it into Postman and start using it to interact with the API. For ease of use, the postman collection uses postman environments to store the variables required to interact with the API. You will need to set the following variables in the postman environment:

- 'HOST' - The hostname/IP of the connector (e.g., `http://localhost`)
- 'PORT' - The port on which the connector is running (e.g., `8080`)
- 'SMB_HOST' - The hostname/IP of the SMB server (e.g., `10.0.0.9`)
- 'SMB_USER' - The username for the SMB server (e.g., `admin`)
- 'SMB_PASSWORD' - The password for the SMB server (e.g., `password`)

### Work directly with the API

The API documentation is available at `http://localhost:8000/docs` after starting the connector.

#### Create a new admin user

Send a POST request to `{{HOST:PORT}}/users/first-admin` with the following payload:

```json
{
  "username": "admin",
  "password": "YourPassword",
  "email": "admin@example.com"
}
```

**_Note_**: This user will be created as an admin user and will have full access to the connector. It will NOT have any connectivity to the NetApp shares of the data contained within them.

You will receive a status 200 acknowledgment if the user is successfully created.

#### Authenticate the user

Send a POST request to `{{HOST:PORT}}/token` with the following payload:

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

Use the `access_token` to authenticate your requests to the API. The postman collection is configured to automatically use the token for subsequent requests.

## 3. Adding Your First Share

Discover how to connect the connector to your NetApp share, enabling file access.

Now that you have an admin user, you can add your first share. Send a POST request to `{{HOST:PORT}}/shares` with the following payload:

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

**_Note_** for details on the rules and filters, see the [Rules and Filters](#rules-and-filters) section below.

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

- `exclude_patterns`: Exclude files matching these patterns (e.g., `["*.tmp", ".git/*"]`)

#### Timestamp Filtering Rules

The connector supports filtering files based on timestamps:

- `min_modified_time`: Only include files modified on or after this time (ISO 8601 format, e.g., "2025-01-01T00:00:00")
- `max_modified_time`: Only include files modified on or before this time
- `min_accessed_time`: Only include files accessed on or after this time
- `max_accessed_time`: Only include files accessed on or before this time
- `min_created_time`: Only include files created on or after this time
- `max_created_time`: Only include files created on or before this time

Setting any of these values to `null` (or omitting them) disables that specific filter.

#### File Size Filtering Rules

The connector supports filtering files based on size:

- `min_file_size`: Only include files larger than this size (in bytes)
- `max_file_size`: Only include files smaller than this size (in bytes)

## 5. Monitoring Operations

Understand how to monitor the connector's operations and troubleshoot any issues.

#### GET /operations

Get operation logs with optional filtering.

Query Parameters:

- `limit` (optional): Maximum number of logs to return (default: 100)
- `operation_type` (optional): Filter by operation type (e.g., "LIST_FILES", "GET_SHARE")

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
  "version": "1.0.0",
  "database": "connected",
  "uptime": "1d 2h 34m"
}
```

## 6. BONUS: Querying Files

The NetApp Connector API provides a powerful search capability to query files based on various criteria. You can search for files based on their metadata, and more in future.

To list all files for a given share, send a GET request to `{{HOST:PORT}}/shares/{share_id}/files`.

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

If you have any feedback or questions regarding the NetApp Connector or its Documentation, please reach out to us open a GitHub issue at [NetApp Innovation Labs](https://github.com/NetApp/Innovation-Labs/issues).
