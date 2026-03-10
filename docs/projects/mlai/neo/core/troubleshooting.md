# Troubleshooting

This guide covers common issues and solutions for NetApp Project Neo v4.0.2 and its multi-service architecture.

## How to log a support case / idea

Please log support cases or ideas via the NetApp Innovations Labs issues portal: [Innovation Labs Issues](https://github.com/NetApp/Innovation-Labs/issues).

## Container won't start

This typically occurs when the connector does not have a valid license key. Ensure that the `NETAPP_CONNECTOR_LICENSE` environment variable is set in the `.env` file and that the license key is valid.

Check the container logs for the specific service that failed:

```bash
docker logs neo-api
docker logs neo-worker
```

If the service exits immediately with no output, verify the image was pulled correctly:

```bash
docker compose pull
docker compose up -d
```

---

## Multi-Service Issues

Neo v4 uses a multi-service architecture with independently scalable components. Issues often stem from services not being able to communicate or starting in the wrong order.

### Services not communicating

**Symptoms:** API returns `502 Bad Gateway` or `"Worker unavailable"` in monitoring responses.

**Solutions:**

1. Verify all services are running:
   ```bash
   docker compose ps
   ```
2. Confirm services are on the same Docker network (`neo-network`):
   ```bash
   docker network inspect neo-network
   ```
3. Check that `WORKER_SERVICE_URL`, `EXTRACTOR_SERVICE_URL`, and `NER_SERVICE_URL` are set correctly. Default values in `docker-compose.yml`:
   - API -> Worker: `http://worker:8000`
   - Worker -> Extractor: `http://extractor:8000`
   - Worker -> NER: `http://ner:8000`
   - API -> NER: `http://ner:8000`
4. Test connectivity from inside a container:
   ```bash
   docker exec neo-api curl -s http://worker:8000/health
   docker exec neo-worker curl -s http://extractor:8000/health
   docker exec neo-worker curl -s http://ner:8000/health
   ```

### Container health checks failing

Each service has a Docker health check that calls its `/health` endpoint. If a service shows as `unhealthy`:

```bash
docker inspect --format='{{json .State.Health}}' neo-api
```

Common causes:
- **start_period not elapsed** — The NER service needs up to 3 minutes (`start_period: 180s`) to load the GLiNER2 model, especially on GPU. Wait for the start period to complete before investigating.
- **Port conflict** — All services listen on port 8000 internally. If you override ports, update health check commands accordingly.
- **Missing `curl`** — Health checks use `curl` inside the container. If a custom image removed it, the health check will fail.

### Service dependency order

Docker Compose enforces startup order via `depends_on` with health check conditions:

1. **postgres** starts first (all other services depend on it)
2. **extractor** and **ner** start after postgres is healthy
3. **worker** starts after postgres, extractor, and ner are all healthy
4. **api** starts after postgres is healthy
5. **neoui** starts after api is healthy

If the worker is stuck in `waiting_for_setup` status, complete initial setup via the API service at `POST /api/v1/setup/`.

---

## Database Issues

### Connection refused

**Error:** `connection refused` or `could not connect to server`

1. Verify PostgreSQL is running:
   ```bash
   docker logs neo-postgres
   docker exec neo-postgres pg_isready -U neo -d neo_connector
   ```
2. Check that `DATABASE_URL` is correct in all services. The format is:
   ```
   postgresql://USER:PASSWORD@HOST:PORT/DBNAME
   ```
3. If using an external PostgreSQL instance (not the bundled container), ensure the host is reachable from the Docker network and that `pg_hba.conf` allows connections from the container subnet (`172.22.0.0/16` by default).

### Migration failures

Database schema migrations run automatically on service startup. If a migration fails:

1. Check the API or worker logs for migration error details:
   ```bash
   docker logs neo-api 2>&1 | grep -i "migration\|alter\|create table"
   ```
2. If a migration was partially applied, the service may fail on restart. Connect to the database and check table state:
   ```bash
   docker exec -it neo-postgres psql -U neo -d neo_connector -c "\dt"
   ```
3. For locking issues during migration (multiple services migrating simultaneously), Neo uses advisory locks. If a migration lock is stuck, restart all services — the lock is session-based and will be released.

### system_config table missing

The `system_config` table stores encryption keys, JWT secrets, and other shared configuration. It is created automatically on first startup by whichever service starts first.

If you see errors about `system_config` not existing:
1. Ensure at least one service (API or worker) has started successfully against the database at least once.
2. Check that the database user has `CREATE TABLE` privileges.

### Encryption key errors

**Error:** `InvalidToken` or `Fernet key error` when accessing shares

The `ENCRYPTION_KEY` is a Fernet key used to encrypt sensitive data (e.g., SMB passwords). It is auto-generated and stored in the `system_config` table on first startup.

- **All services must use the same encryption key.** If services share the same `DATABASE_URL`, they retrieve the key from the database automatically.
- If you set `ENCRYPTION_KEY` as an environment variable, it overrides the database-stored key. Ensure all services use the same value.
- If the key was rotated or lost, encrypted passwords in the database are unrecoverable. You will need to re-enter share credentials.

---

## MCP / OAuth Issues

### Token validation failing

**Symptoms:** MCP clients receive `401 Unauthorized` when connecting.

1. If `MCP_OAUTH_ENABLED=true`, verify Entra ID configuration:
   - `MCP_OAUTH_TENANT_ID` — must match the Entra tenant
   - `MCP_OAUTH_CLIENT_ID` — must match the app registration
   - `MCP_OAUTH_AUDIENCE` — must match the `aud` claim in the token
2. Check token expiry — if clocks are skewed between the issuer and Neo, tokens may appear expired. Ensure NTP is configured on the host.
3. Test with a fresh token:
   ```bash
   curl -H "Authorization: Bearer <token>" http://localhost:8000/mcp/
   ```

### MCP API key invalid

When `MCP_API_KEY` is set, clients send it as a Bearer token instead of going through OAuth:

```bash
curl -H "Authorization: Bearer <your-api-key>" http://localhost:8000/mcp/
```

- Ensure the API key value matches exactly (no trailing whitespace or newlines).
- The API key can also be managed via: `POST /api/v1/setup/mcp/api-key`.
- Generate a secure key: `python3 -c "import secrets; print(secrets.token_urlsafe(48))"`.

### Entra ID groups not resolving

If ACL resolution cannot map SMB permissions to Entra ID identities:

1. Verify `MS_GRAPH_TENANT_ID`, `MS_GRAPH_CLIENT_ID`, and `MS_GRAPH_CLIENT_SECRET` are correct.
2. The Entra app registration must have `User.Read.All` and `Group.Read.All` (or `GroupMember.Read.All`) API permissions with admin consent granted.
3. Check the worker logs for Graph API errors:
   ```bash
   docker logs neo-worker 2>&1 | grep -i "acl\|entra\|group\|403"
   ```
4. If `ACL_STRICT_MODE=true` (default), files with unresolvable ACLs are skipped. Set to `false` to fall back to tenant-wide access (not recommended for production).

### Rate limiting too aggressive on MCP

If MCP clients are being throttled, check whether the Graph API rate limiter is affecting overall API responsiveness. The Graph rate limit defaults to 25 requests/second. Adjust via:

```
GRAPH_RATE_LIMIT=25.0
```

Monitor current rate limit status:
```bash
curl -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/monitoring/graph-rate-limit
```

---

## Graph Sync Issues

### Connector not created

Before files can be synced to Microsoft 365 Copilot, a Graph connector must be registered:

1. Ensure Graph credentials are configured (tenant ID, client ID, client secret).
2. Check that `MS_GRAPH_CONNECTOR_ID` is set (default: `netappneo`).
3. The Entra app registration must have `ExternalConnection.ReadWrite.All` and `ExternalItem.ReadWrite.All` application permissions.
4. Create the connector via the API or UI, or check its status:
   ```bash
   curl -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/setup/graph/status
   ```

### Indexing stuck or slow

**Symptoms:** Work queue shows items stuck in `processing` or `claimed` status.

1. Check the monitoring overview for queue depth:
   ```bash
   curl -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/monitoring/overview
   ```
2. Check for failed items:
   ```bash
   curl -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/monitoring/failed-items
   ```
3. Retry failed items:
   ```bash
   curl -X POST -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/monitoring/retry-failed
   ```
4. If items are stuck in `claimed` but not progressing, workers may have crashed. Restart the worker service — abandoned items are automatically reclaimed.
5. Scale workers for higher throughput:
   ```bash
   docker compose up -d --scale worker=3
   ```

### Permission mapping failures

When uploading to Graph, Neo maps SMB/NFS ACLs to Entra ID identities. Failures are common when:

- Domain users do not have corresponding Entra ID accounts
- SID-to-UPN mapping fails due to domain trust issues
- The Entra app lacks `User.Read.All` permission

Check the failed items endpoint for specific ACL errors and consider setting `ACL_STRICT_MODE=false` temporarily for testing.

### Graph API rate limit exceeded

**Error:** `429 Too Many Requests` in worker logs.

Neo has built-in rate limiting and exponential backoff. If you see persistent 429s:

1. Reduce `NUM_UPLOAD_WORKERS` (default: 3) to lower concurrency.
2. Lower `GRAPH_RATE_LIMIT` (default: 25.0 req/s).
3. Increase `GRAPH_API_MAX_RETRIES` (default: 3) to allow more retries.
4. Monitor throttling status:
   ```bash
   curl -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/monitoring/graph-rate-limit
   ```

---

## Content Extraction Issues

### Large file timeouts

**Error:** Extraction requests timing out for large documents.

1. The extractor service has a default processing timeout. For very large files (hundreds of pages), increase the timeout by scaling extractor instances:
   ```bash
   docker compose up -d --scale extractor=5
   ```
2. Check `EXTRACTOR_MOUNT_TTL` (default: 3600s) — ensure it exceeds the longest expected extraction time.
3. Consider switching the extraction pipeline for problem files:
   - `markitdown` — fast, good for Office and simple PDFs
   - `docling` — slower but better for complex layouts, OCR, and tables
   - `vlm` — uses vision language models for diagrams, charts, handwriting (requires GPU or remote API)

### Unsupported file formats

The extractor service supports a wide range of formats. Check available extractors and their supported extensions:

```bash
curl http://localhost:8000/health/detailed  # (on the extractor service, port depends on mapping)
# Or from inside the network:
docker exec neo-worker curl -s http://extractor:8000/health/detailed
```

Files with unsupported extensions are skipped during crawling. Check the work queue for items with `failed` status and `unsupported format` in the error details.

### GPU extraction failing

**Symptoms:** Extractor falls back to CPU, or VLM extraction fails.

1. Verify GPU is accessible inside the container:
   ```bash
   docker exec neo-extractor nvidia-smi
   ```
2. Ensure the GPU variant of the extractor image is being used (CUDA or ROCm).
3. Check that `EXTRACTOR_FORCE_CPU` is not set to `true`.
4. For VLM models, ensure `VLM_MODEL` is set correctly. Options:
   - `SMOLDOCLING_TRANSFORMERS` — local SmolDocling model (needs GPU)
   - `GRANITEDOCLING_TRANSFORMERS` — local Granite model (needs GPU)
   - `api` — remote vLLM/Ollama endpoint (set `VLM_API_URL` and `VLM_API_MODEL`)
5. For AMD GPUs (ROCm), use device passthrough instead of the NVIDIA deploy block:
   ```yaml
   devices:
     - /dev/kfd:/dev/kfd
     - /dev/dri:/dev/dri
   group_add:
     - video
     - render
   ```

### NER results not appearing

**Symptoms:** Files are extracted but no entities, classifications, or structured data appear.

1. Verify the NER service is running and healthy:
   ```bash
   docker exec neo-worker curl -s http://ner:8000/health
   ```
2. Check that `ENABLE_NER_ANALYSIS=true` is set on the worker service.
3. Check `NER_CONFIDENCE_THRESHOLD` (default: 0.7) — if set too high, entities with lower confidence are filtered out. Lower it to 0.5 for more results.
4. Check the NER service detailed health for processing stats:
   ```bash
   docker exec neo-worker curl -s http://ner:8000/health/detailed
   ```
5. If the NER model failed to load (e.g., out of memory on GPU), the service will report `model_loaded: false`. Try setting `NER_DEVICE=cpu` or increasing `NER_CUDA_MAX_TEXT_LENGTH`.
6. Check that `NUM_NER_WORKERS` (default: 1) is not set to 0.

---

## Performance Issues

### Search is slow

Neo v4 uses PostgreSQL GIN-indexed `search_vector` columns for full-text search, providing 20-42x speedup over unindexed queries.

If search is slow:

1. Verify the GIN index exists:
   ```sql
   SELECT indexname FROM pg_indexes WHERE tablename = 'file_metadata' AND indexname = 'idx_file_metadata_search_vector';
   ```
2. If the index is missing, it is created automatically during migration. Restart the API service to trigger migration.
3. For large databases, `VACUUM ANALYZE file_metadata` can help the query planner:
   ```bash
   docker exec neo-postgres psql -U neo -d neo_connector -c "VACUUM ANALYZE file_metadata;"
   ```
4. Check that queries are using `websearch_to_tsquery` (the indexed path) rather than `LIKE` or `ILIKE` patterns.

### ACL resolution slow

ACL resolution maps SMB/NFS permissions to Entra ID identities via the Microsoft Graph API. If resolution is slow:

1. Increase `NUM_ACL_RESOLUTION_WORKERS` (default: 2) for more parallelism.
2. Check for Graph API throttling (429 responses) — ACL lookups count toward the rate limit.
3. Resolved identities are cached. Initial resolution is slower than subsequent runs.

### Rate limiter too restrictive

If the overall system throughput is lower than expected:

1. Increase `GRAPH_RATE_LIMIT` (default: 25.0 req/s). Microsoft allows higher rates for some tenants.
2. Increase worker concurrency:
   - `NUM_UPLOAD_WORKERS` (default: 3)
   - `NUM_EXTRACTION_WORKERS` (default: 2)
   - `NUM_ACL_RESOLUTION_WORKERS` (default: 2)
3. Scale services horizontally:
   ```bash
   docker compose up -d --scale worker=3 --scale extractor=5 --scale ner=2
   ```
4. Use the benchmark tool to measure bottlenecks:
   ```bash
   curl -X POST -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/monitoring/benchmark/run?sample_size=100
   ```
5. Check auto-tuning recommendations:
   ```bash
   curl -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/monitoring/tuning/recommendations
   ```

---

## Common Error Messages

| Error Message | Cause | Solution |
|---|---|---|
| `InvalidToken` or `Fernet key error` | Encryption key mismatch between services | Ensure all services share the same `DATABASE_URL` or set the same `ENCRYPTION_KEY` |
| `connection refused` on port 5432 | PostgreSQL not running or unreachable | Check `docker logs neo-postgres` and verify `DATABASE_URL` |
| `system_config table does not exist` | Database not initialized | Restart the API service to trigger auto-migration |
| `429 Too Many Requests` | Microsoft Graph rate limit exceeded | Reduce `NUM_UPLOAD_WORKERS` or lower `GRAPH_RATE_LIMIT` |
| `401 Unauthorized` on MCP endpoints | Invalid OAuth token or API key | Verify `MCP_OAUTH_*` settings or `MCP_API_KEY` value |
| `502 Bad Gateway` from API | Worker service unreachable | Check `docker compose ps` and `WORKER_SERVICE_URL` |
| `Worker is waiting for setup` | Initial setup not completed | Complete setup via `POST /api/v1/setup/` or the UI |
| `model_loaded: false` on NER | GLiNER2 model failed to load | Check NER logs; try `NER_DEVICE=cpu` if GPU OOM |
| `ExternalConnection.ReadWrite.All` permission error | Entra app missing Graph permissions | Add required permissions and grant admin consent |
| `SSL: CERTIFICATE_VERIFY_FAILED` | Corporate proxy intercepting SSL | Set `GRAPH_CA_BUNDLE` to your CA cert path, or set `GRAPH_ALLOW_LEGACY_CERTIFICATES=true` |
| `unsupported format` | File type not handled by any extractor | Check `/health/detailed` on extractor for supported extensions |

---

## Log Locations

All services log to stdout/stderr, accessible via Docker:

| Service | Container Name | Command |
|---|---|---|
| API | `neo-api` (or auto-named) | `docker logs neo-api` |
| Worker | `neo-worker` (or auto-named) | `docker logs neo-worker` |
| Extractor | `neo-extractor` (or auto-named) | `docker logs neo-extractor` |
| NER | `neo-ner` (or auto-named) | `docker logs neo-ner` |
| PostgreSQL | `neo-postgres` | `docker logs neo-postgres` |
| UI | `neoui` | `docker logs neoui` |

::: tip
Use `docker compose logs -f <service>` to follow logs from a specific service in real time. For example: `docker compose logs -f worker`.
:::

To filter for errors:
```bash
docker logs neo-worker 2>&1 | grep -i "error\|exception\|failed"
```

Adjust log verbosity per service:
- Extractor: `EXTRACTOR_LOG_LEVEL=DEBUG`
- NER: `NER_LOG_LEVEL=DEBUG`

---

## Health Check Endpoints

Every service exposes two health endpoints (no authentication required):

### `GET /health`

Basic health check for load balancers and orchestration. Returns HTTP 200 with service status.

| Service | URL (internal) | Response Fields |
|---|---|---|
| API | `http://api:8000/health` | `status`, `service`, `version`, `timestamp` |
| Worker | `http://worker:8000/health` | `status`, `service`, `version`, `timestamp` |
| Extractor | `http://extractor:8000/health` | `status`, `service` |
| NER | `http://ner:8000/health` | `status`, `service`, `model_loaded` |

The worker service returns `status: waiting_for_setup` if initial setup has not been completed.

### `GET /health/detailed`

Detailed health check with component-level status. Useful for diagnosing degraded service states.

| Service | URL (internal) | Additional Details |
|---|---|---|
| API | `http://api:8000/health/detailed` | Database status, OAuth configuration, worker URL |
| Worker | `http://worker:8000/health/detailed` | Database, VFS, Graph connector, worker thread status |
| Extractor | `http://extractor:8000/health/detailed` | Available extractors, supported extensions, GPU/device info |
| NER | `http://ner:8000/health/detailed` | Engine status, model info, processing stats (requests, entities, avg latency) |

### `GET /ready` (API only)

Kubernetes-style readiness probe. Returns HTTP 200 when the database is connected, or HTTP 503 if not ready.

```bash
# Quick check of all services from the host
curl -s http://localhost:8000/health          # API (exposed port)
docker exec neo-worker curl -s http://localhost:8000/health       # Worker
docker exec neo-worker curl -s http://extractor:8000/health       # Extractor
docker exec neo-worker curl -s http://ner:8000/health             # NER
```

---

## Frequently Asked Questions (FAQ)

### What is NetApp Project Neo?

NetApp Project Neo is a containerized multi-service platform that enables you to connect any NetApp storage platform to Microsoft 365 Copilot without migrating files or rearchitecting your data. It provides content extraction, named entity recognition, and intelligent indexing through a set of independently scalable microservices (API, worker, extractor, NER) with an API and web UI for management.

### What are the supported storage sources?

NetApp Project Neo supports the following protocols and platforms:

- **SMB File Shares** (v3.1.1 through v2.0). SMB 3.1.1 is recommended for optimal performance due to multi-channel support. This includes:
  - Azure NetApp Files (ANF)
  - AWS FSxN
  - Google Cloud Volumes NetApp (GCVN)
  - Cloud Volumes ONTAP (CVO)
  - Any ONTAP-based system (FAS, AFF, Select, etc.)
- **NFS Exports** — NFS v3 and v4.x shares are supported for content crawling and extraction.
- **S3-Compatible Object Storage** — S3 buckets are supported as a source, including NetApp StorageGRID, Amazon S3, and S3-compatible endpoints.

### What about non-NetApp sources?

NetApp Project Neo operates at the protocol level and is not specifically locked to NetApp platforms. Any storage accessible via SMB, NFS, or S3 can be connected. Please reach out to your NetApp representative for more information.

### How is NetApp Project Neo licensed?

NetApp Project Neo is licensed per licensed user of M365 Copilot. The license is perpetual and includes 1 year of support and maintenance. The license is tied to the connector and is not transferable. The license does not require an internet connection for activation.

### Does NetApp Project Neo support multiple file shares?

Yes. You can configure multiple shares (SMB, NFS, or S3) and manage them through the API or web UI. The shares API endpoint is available for managing and monitoring all configured sources. There is no hard limit on the number of shares, though real-world deployments should be tested for performance. Scale worker and extractor instances to handle higher share counts.

### Does NetApp Project Neo support proxies and SSL inspection?

Yes. Proxy and SSL are fully supported. Configure the following environment variables on the API and worker services:

- `HTTPS_PROXY` — proxy URL for outbound HTTPS traffic (e.g., `http://proxy.corp.com:8080`)
- `GRAPH_CA_BUNDLE` — path to a custom CA certificate bundle (mount the cert file into the container)
- `GRAPH_VERIFY_SSL` — set to `false` to disable SSL verification (not recommended for production)
- `GRAPH_ALLOW_LEGACY_CERTIFICATES` — set to `true` to accept legacy X.509 certificates (needed for some corporate proxies on Python 3.13+)

### How do I upgrade NetApp Project Neo?

Pull the latest images and redeploy:

```bash
docker compose pull
docker compose up -d
```

Database migrations are applied automatically on startup. Ensure that you have a valid license key. It is recommended to back up the PostgreSQL data volume before upgrading.

### The connector starts, then stops immediately

This typically occurs when the connector does not have a valid license key. Ensure that the `NETAPP_CONNECTOR_LICENSE` environment variable is set in the `.env` file and that the license key is valid. Check logs with `docker logs neo-api` for the specific error.

### How does Microsoft 365 Copilot work for organizations with multiple regions?

All graph data is stored in the **Primary Provisioned Geography** location. This applies even if an organization has satellite regions, as explained here [Plan for Microsoft 365 Multi-Geo - Microsoft 365 Enterprise | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/enterprise/plan-for-multi-geo?view=o365-worldwide) but the graph index is only in the primary region (in order to provide a unified search experience across all the tenants).

### How do I scale for better performance?

Neo v4 services can be scaled independently:

```bash
docker compose up -d --scale worker=3 --scale extractor=5 --scale ner=2
```

Use the built-in benchmark and auto-tuning endpoints to identify bottlenecks:
- `POST /api/v1/monitoring/benchmark/run` — run a benchmark
- `GET /api/v1/monitoring/tuning/recommendations` — get tuning suggestions
- `GET /api/v1/monitoring/sizing/current` — compare current config to recommended profiles
