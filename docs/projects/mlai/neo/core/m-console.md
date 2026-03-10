# Neo Console

## Access the web management interface

The Neo Console is a web-based management interface that connects to the API service. It can be accessed by navigating to `http://<server-ip>:8081` in your web browser, where `<server-ip>` is the IP address of the server where NetApp Project Neo is deployed. If you are using ingress, use the appropriate URL configured for access.

If the web interface is not accessible, ensure that the API service is running on port 8000 and that there are no firewall rules blocking access to port 8081.

On first access, you will be prompted to log in. Use the default credentials provided during installation. It is highly recommended to change the default password upon first login for security purposes. If you have forgotten your password, run the following command to retrieve the auto-generated admin password:

```bash
curl --location 'http://<server-ip>:8000/api/v1/setup/initial-credentials'
```

> [!NOTE]
> The above command will only work if the admin user has never logged in before. If the admin user has logged in previously, you will need to reset the password via the API or database.

## Search

The console provides a full-text search interface for querying indexed content across all configured shares. Search features include:

- **Full-text search**: Search across all extracted document content using natural language queries. Results are ranked by relevance using PostgreSQL GIN-indexed search vectors.
- **Filters**: Narrow results by share, file type, date range, or NER entity tags.
- **File preview**: View extracted content and metadata for any search result.
- **Export**: Download search results for further analysis.

## Operations

The console provides an operations dashboard for managing Neo services and monitoring system health:

- **Share management**: Add, edit, and remove SMB shares. Configure crawl schedules, include/exclude patterns, and authentication settings.
- **Crawl monitoring**: View active crawls, progress, file counts, and error logs in real time.
- **Task queue**: Monitor the worker task queue, view pending and completed jobs, and retry failed tasks.
- **NER status**: View Named Entity Recognition processing status and results per share.
- **Graph sync**: Monitor Microsoft 365 Copilot connector sync status, including upload progress and errors.
- **System health**: View service status, database size, and resource utilization.
- **User management**: Create, edit, and deactivate user accounts and manage roles.
