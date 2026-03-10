# Upgrades

## v3.x to v4.x Migration Guide

> [!IMPORTANT]
> v4 is a major architectural change from a monolithic application to a microservices architecture with four separate services (API, Worker, Extractor, NER). A direct in-place upgrade from v3 is not supported. Follow this guide carefully.

### Step 1: Back Up Your Database

Before starting any migration, create a full backup of your existing database.

```bash
# PostgreSQL
pg_dump -h <host> -U <user> -d neo -F c -f neo_v3_backup.dump

# MySQL
mysqldump -h <host> -u <user> -p neo > neo_v3_backup.sql
```

Verify the backup is complete and store it in a safe location.

### Step 2: Document Your Current Configuration

Record your existing v3 environment variables before proceeding. You will need to map them to the new v4 configuration.

### Step 3: Environment Variable Mapping

The following environment variables have changed between v3 and v4:

| v3 Variable | v4 Variable | Notes |
|------------|------------|-------|
| `DATABASE_URL` | `DATABASE_URL` | Unchanged |
| `MS_GRAPH_CLIENT_ID` | `MS_GRAPH_CLIENT_ID` | Unchanged, now set via API or env var |
| `MS_GRAPH_CLIENT_SECRET` | `MS_GRAPH_CLIENT_SECRET` | Unchanged, now set via API or env var |
| `MS_GRAPH_TENANT_ID` | `MS_GRAPH_TENANT_ID` | Unchanged, now set via API or env var |
| `NETAPP_CONNECTOR_LICENSE` | `NETAPP_NEO_LICENSE` | Renamed |
| `ENCRYPTION_KEY` | `ENCRYPTION_KEY` | Unchanged, must be consistent across all services |
| N/A | `WORK_QUEUE_URL` | New: connection URL for inter-service work queue |
| N/A | `EXTRACTOR_URL` | New: URL for the extractor service |
| N/A | `NER_URL` | New: URL for the NER service |

> [!NOTE]
> In v4, Graph credentials can also be configured via the setup API (`POST /api/v1/setup/graph`) instead of environment variables.

### Step 4: Deploy v4 Services

1. **Download the v4 Docker Compose file** from the [NetApp Neo GitHub repository](https://raw.githubusercontent.com/NetApp/Innovation-Labs/refs/heads/main/netapp-neo/dist/docker-compose.yml).

2. **Update environment variables** using the mapping table above. The v4 compose file defines four services (`api`, `worker`, `extractor`, `ner`) plus a PostgreSQL database.

3. **Point v4 at your existing database.** Set the `DATABASE_URL` in the new compose file to your existing PostgreSQL database. If migrating from MySQL, you will need to export and import data to PostgreSQL first, as v4 uses PostgreSQL as the primary database.

4. **Start the v4 services:**

   ```bash
   docker compose up -d
   ```

### Step 5: Automatic Database Migrations

On first startup, the v4 API service will automatically run any required database migrations. This includes:

- Adding new tables for the microservices work queue
- Adding search vector columns and GIN indexes for full-text search
- Adding NER-related tables and columns
- Updating schema for multi-service architecture

Monitor the API service logs during first startup to confirm migrations complete successfully:

```bash
docker compose logs -f api
```

### Step 6: Verify the Migration

1. Access the API at `http://<server-ip>:8000/docs` to confirm the API service is running.
2. Access the console at `http://<server-ip>:8081` to confirm the UI is available.
3. Check that your existing shares appear in the share list.
4. Trigger a test crawl on a small share to verify end-to-end processing.

### Data Preservation Notes

- **File metadata**: Preserved during migration. Existing file records remain intact.
- **Extracted content**: Preserved if stored in the database.
- **NER results**: v3 NER results are preserved. v4 uses an updated NER pipeline that may produce different results on re-processing.
- **ACLs**: Preserved. ACL structure is unchanged between v3 and v4.
- **Graph connections**: You will need to re-enter Graph credentials via the setup API or environment variables after migration.

## Upgrading Within v4.x

To upgrade between v4.x patch releases (e.g., v4.0.1 to v4.0.2):

```bash
# Pull the latest images
docker compose pull

# Restart with new images
docker compose up -d
```

Database migrations, if any, run automatically on startup. No manual intervention is required for patch upgrades.
