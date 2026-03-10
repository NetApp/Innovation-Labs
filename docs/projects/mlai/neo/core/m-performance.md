# Performance & Benchmarking

This guide covers Neo's built-in benchmarking system, sizing profiles, auto-tuning, and manual performance tuning for production deployments.

---

## Table of Contents

1. [Benchmarking System](#benchmarking-system)
2. [Benchmark API Endpoints](#benchmark-api-endpoints)
3. [Sizing Profiles](#sizing-profiles)
4. [Auto-Tuning](#auto-tuning)
5. [Manual Tuning](#manual-tuning)
6. [Independent Service Scaling](#independent-service-scaling)

---

## Benchmarking System

Neo includes a 5-stage benchmark pipeline that measures throughput, latency, and error rates across each stage of the processing pipeline. The system automatically identifies the bottleneck stage and generates tuning recommendations.

### Pipeline Stages

| Stage | What It Measures |
|---|---|
| **Database** | Read query throughput and latency against `file_inventory` |
| **Enumeration** | File discovery and directory scanning performance |
| **Extraction** | Content extraction throughput from historical completed work items |
| **ACL Extraction** | ACL/permission resolution throughput from completed ACL work items |
| **Graph Upload** | Microsoft Graph API upload throughput, including rate-limit detection |

### Metrics Per Stage

Each stage reports:

- **Throughput** (items/second) -- sustained processing rate
- **Average latency** (ms) -- mean time per operation
- **P95 latency** (ms) -- 95th percentile latency
- **Error rate** -- fraction of operations that failed
- **Sample size** -- number of operations measured

### Bottleneck Detection

After all stages complete, the system identifies the stage with the lowest throughput as the pipeline bottleneck. Recommendations are then generated targeting the bottleneck:

- **Extraction bottleneck**: Increase `NUM_EXTRACTION_WORKERS` or `CONTENT_EXTRACTION_PARALLEL_WORKERS`
- **Graph upload bottleneck**: Adjust `NUM_UPLOAD_WORKERS` or `GRAPH_RATE_LIMIT` (reduce rate if 429 throttling is active)
- **Database bottleneck**: Increase `DATABASE_BATCH_INSERT_SIZE` or `DATABASE_CONNECTION_POOL_SIZE`
- **ACL extraction bottleneck**: Increase `MAX_CONCURRENT_WORK`
- **Enumeration bottleneck**: Increase `MAX_ENUMERATION_WORKERS`

---

## Benchmark API Endpoints

All benchmark endpoints require authentication. The benchmark runs on the worker service; the API proxies requests to it.

### Start a Benchmark

**`POST /api/v1/monitoring/benchmark/run`**

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `share_id` | string | No | all shares | Scope benchmark to a specific share |
| `sample_size` | integer | No | 100 | Number of items to sample per stage |
| `stages` | string | No | all stages | Comma-separated list: `database,enumeration,extraction,acl_extraction,graph_upload` |

```bash
curl -X POST "http://localhost:8000/api/v1/monitoring/benchmark/run?sample_size=200" \
  -H "Authorization: Bearer $TOKEN"
```

Run only specific stages:

```bash
curl -X POST "http://localhost:8000/api/v1/monitoring/benchmark/run?stages=database,extraction&sample_size=50" \
  -H "Authorization: Bearer $TOKEN"
```

### Check Benchmark Status

**`GET /api/v1/monitoring/benchmark/status`**

Returns whether a benchmark is currently running.

```bash
curl http://localhost:8000/api/v1/monitoring/benchmark/status \
  -H "Authorization: Bearer $TOKEN"
```

### Get Latest Results

**`GET /api/v1/monitoring/benchmark/results`**

Returns the most recent benchmark result with per-stage metrics, bottleneck analysis, and recommendations.

```bash
curl http://localhost:8000/api/v1/monitoring/benchmark/results \
  -H "Authorization: Bearer $TOKEN"
```

#### Example Response

```json
{
  "benchmark_id": "a1b2c3d4-...",
  "timestamp": "2026-03-10T14:30:00Z",
  "duration_ms": 4521,
  "system_info": {
    "cpu_count": 8,
    "platform": "Linux",
    "ram_total_gb": 16.0,
    "ram_available_gb": 9.2,
    "ram_percent_used": 42.5,
    "cpu_percent": 35.0
  },
  "stages": {
    "database": {
      "stage": "database",
      "throughput": 1250.0,
      "avg_latency_ms": 0.8,
      "p95_latency_ms": 1.2,
      "error_rate": 0.0,
      "sample_size": 200
    },
    "extraction": {
      "stage": "extraction",
      "throughput": 12.5,
      "avg_latency_ms": 80.0,
      "p95_latency_ms": 250.0,
      "error_rate": 0.0,
      "sample_size": 200
    }
  },
  "bottleneck": "extraction",
  "recommendations": [
    {
      "parameter": "NUM_EXTRACTION_WORKERS",
      "current_value": 1,
      "recommended_value": 2,
      "expected_improvement": "~2x extraction throughput",
      "reason": "Extraction is the bottleneck; adding workers distributes CPU load"
    }
  ],
  "status": "completed"
}
```

### Get Benchmark History

**`GET /api/v1/monitoring/benchmark/history`**

Returns up to the last 20 benchmark results, allowing you to track performance changes over time.

```bash
curl http://localhost:8000/api/v1/monitoring/benchmark/history \
  -H "Authorization: Bearer $TOKEN"
```

---

## Sizing Profiles

Neo ships with four sizing profiles based on file estate size. The system auto-detects the appropriate profile by examining available CPU and RAM.

| Profile | File Estate | CPU | RAM | Extraction Workers | Upload Workers | Graph Rate Limit |
|---|---|---|---|---|---|---|
| **Small** | < 10K files | 2 cores | 4 GB | 1 | 2 | 20 req/s |
| **Medium** | 10K - 100K files | 4 cores | 8 GB | 2 | 3 | 25 req/s |
| **Large** | 100K - 1M files | 8 cores | 16 GB | 4 | 6 | 40 req/s |
| **Enterprise** | > 1M files | 16 cores | 32 GB | 8 | 10 | 50 req/s |

### Get All Profiles

**`GET /api/v1/monitoring/sizing/profiles`**

```bash
curl http://localhost:8000/api/v1/monitoring/sizing/profiles \
  -H "Authorization: Bearer $TOKEN"
```

### Get Current Sizing Assessment

**`GET /api/v1/monitoring/sizing/current`**

Compares your current configuration against the recommended profile for your hardware. Returns the auto-detected profile, current parameter values, recommended values, and any deltas.

```bash
curl http://localhost:8000/api/v1/monitoring/sizing/current \
  -H "Authorization: Bearer $TOKEN"
```

#### Example Response

```json
{
  "system": {
    "cpu_count": 8,
    "ram_gb": 16.0
  },
  "recommended_profile": "large",
  "recommended_profile_label": "Large (100K-1M files)",
  "current_values": {
    "NUM_EXTRACTION_WORKERS": 2,
    "NUM_UPLOAD_WORKERS": 3
  },
  "recommended_values": {
    "NUM_EXTRACTION_WORKERS": 4,
    "NUM_UPLOAD_WORKERS": 6
  },
  "deltas": [
    {
      "parameter": "NUM_EXTRACTION_WORKERS",
      "current_value": 2,
      "recommended_value": 4,
      "direction": "increase"
    }
  ],
  "delta_count": 1
}
```

### Get All Tunable Parameters

**`GET /api/v1/monitoring/sizing/parameters`**

Returns every tunable parameter with its description, default, min/max, current value, category, and whether it can be safely auto-adjusted at runtime.

```bash
curl http://localhost:8000/api/v1/monitoring/sizing/parameters \
  -H "Authorization: Bearer $TOKEN"
```

---

## Auto-Tuning

Neo can generate and apply tuning recommendations based on benchmark results. The auto-tuner identifies parameters that are safe to adjust at runtime (flagged `safe_auto_adjust: true`) and suggests changes based on the detected bottleneck.

### Get Recommendations

**`GET /api/v1/monitoring/tuning/recommendations`**

Returns the current set of tuning recommendations from the most recent benchmark.

```bash
curl http://localhost:8000/api/v1/monitoring/tuning/recommendations \
  -H "Authorization: Bearer $TOKEN"
```

### Apply a Tuning Change

**`POST /api/v1/monitoring/tuning/apply`**

Manually apply a specific parameter change. Use this to act on recommendations or to make targeted adjustments.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `parameter` | string | Yes | Environment variable name to change |
| `value` | string | Yes | New value |
| `reason` | string | No | Reason for the change (default: `manual`) |

```bash
curl -X POST "http://localhost:8000/api/v1/monitoring/tuning/apply?parameter=MAX_CONCURRENT_WORK&value=15&reason=benchmark%20recommendation" \
  -H "Authorization: Bearer $TOKEN"
```

### Rollback Last Change

**`POST /api/v1/monitoring/tuning/rollback`**

Reverts the most recent tuning change to its previous value.

```bash
curl -X POST http://localhost:8000/api/v1/monitoring/tuning/rollback \
  -H "Authorization: Bearer $TOKEN"
```

### Get Tuning History

**`GET /api/v1/monitoring/tuning/history`**

Returns a log of all applied tuning changes with timestamps, old values, new values, and reasons.

```bash
curl http://localhost:8000/api/v1/monitoring/tuning/history \
  -H "Authorization: Bearer $TOKEN"
```

### Get Tuning Status

**`GET /api/v1/monitoring/tuning/status`**

Returns whether the auto-tuner is enabled and its current state.

```bash
curl http://localhost:8000/api/v1/monitoring/tuning/status \
  -H "Authorization: Bearer $TOKEN"
```

---

## Manual Tuning

The following environment variables control Neo's performance characteristics. Set them in your Docker Compose file, Kubernetes deployment, or container runtime environment.

### Worker Concurrency

| Variable | Default | Description |
|---|---|---|
| `NUM_EXTRACTION_WORKERS` | 1 | Number of extraction worker processes. Scale with available CPU cores (max 16). Requires restart. |
| `NUM_UPLOAD_WORKERS` | 3 | Number of Graph upload worker tasks. Scale with network bandwidth (max 16). Requires restart. |
| `EXTRACTION_THREAD_POOL_SIZE` | 0 (auto) | Thread pool size per extraction worker. 0 = auto-detect from CPU count (max 32). Requires restart. |
| `MAX_CONCURRENT_WORK` | 10 | Maximum concurrent work items per worker. Higher = more parallelism but more memory pressure (max 50). Safe to adjust at runtime. |
| `CONTENT_EXTRACTION_PARALLEL_WORKERS` | 4 | Parallel threads within a single extraction work item for multi-page documents (max 16). Safe to adjust at runtime. |

### Enumeration

| Variable | Default | Description |
|---|---|---|
| `MAX_ENUMERATION_WORKERS` | 4 | Parallel directory scanning workers (max 16). Safe to adjust at runtime. |
| `ENUMERATION_STRATEGY` | `auto` | Scanning strategy: `auto`, `directory_parallel`, `depth_parallel`, `hybrid`, `single_worker`. |
| `ENUMERATION_TIMEOUT` | 3600 | Maximum seconds for a full share enumeration. Increase for very large shares. |
| `MAX_DEPTH_PER_WORKER` | 3 | Maximum directory depth each enumeration worker processes. |

### Batch Sizes

| Variable | Default | Description |
|---|---|---|
| `DIRECTORY_BATCH_SIZE` | 100 | Directories processed per batch during enumeration (max 1000). |
| `FILE_BATCH_SIZE` | 1000 | Files inserted per database batch (max 10000). |
| `WORK_QUEUE_BATCH_SIZE` | 50 | Work items created per batch (max 500). |
| `DATABASE_BATCH_INSERT_SIZE` | 500 | General database batch insert size (max 5000). |

### Microsoft Graph Rate Limiting

| Variable | Default | Description |
|---|---|---|
| `GRAPH_RATE_LIMIT` | 25.0 | Requests per second to the Graph API. Higher = faster uploads but risk of 429 throttling. |
| `GRAPH_DAILY_QUOTA` | 100000 | Maximum Graph API requests per day. |
| `GRAPH_BACKOFF_BASE_DELAY` | 1.0 | Initial backoff delay (seconds) after a 429 response. |
| `GRAPH_BACKOFF_MAX_DELAY` | 300.0 | Maximum backoff delay (seconds) after repeated 429s. |
| `GRAPH_BACKOFF_MULTIPLIER` | 2.0 | Exponential backoff multiplier. |

### Timeouts

| Variable | Default | Description |
|---|---|---|
| `WORK_PROCESSING_TIMEOUT` | 7200 | Maximum seconds to process a single work item. |
| `FILE_EXTRACTION_TIMEOUT` | 300 | Maximum seconds to extract content from a single file. |
| `GRAPH_UPLOAD_TIMEOUT` | 120 | Maximum seconds for a single Graph API upload. |
| `FS_SCAN_TIMEOUT_PER_DIRECTORY` | 60 | Maximum seconds to scan a single directory. |

### Database

| Variable | Default | Description |
|---|---|---|
| `DATABASE_CONNECTION_POOL_SIZE` | 10 | Connection pool size. More connections = higher DB parallelism (max 50). Requires restart. |
| `DATABASE_QUERY_TIMEOUT` | 30 | Query timeout in seconds (max 300). Requires restart. |

### Content Extraction

| Variable | Default | Description |
|---|---|---|
| `CONTENT_EXTRACTION_MAX_SIZE` | 10 MB | Maximum file size for content extraction. Files larger than this are skipped. |
| `CONTENT_CHUNK_SIZE` | 900 KB | Content chunk size for database storage. Content larger than this is split into multiple rows. |
| `GRAPH_CONTENT_CHUNK_SIZE` | 3.8 MB | Maximum content size per Microsoft Graph external item. |

---

## Independent Service Scaling

Neo consists of four microservices that can be scaled independently based on your workload bottleneck.

### When to Scale the Worker Service

The worker service handles file enumeration, work queue management, and Graph API uploads. Scale it when:

- **Enumeration is slow**: Multiple shares or very deep directory trees benefit from additional worker replicas.
- **Graph upload is the bottleneck**: If the benchmark shows `graph_upload` as the bottleneck and you have headroom in your Graph API rate limit, additional worker replicas increase upload parallelism.
- Increase `NUM_UPLOAD_WORKERS` per replica before adding replicas.

### When to Scale the Extractor Service

The extractor service performs content extraction (text from PDFs, Office documents, images via OCR). Scale it when:

- **Extraction is the bottleneck**: The benchmark consistently identifies `extraction` as the slowest stage.
- **Large or complex documents**: PDF-heavy estates with scanned documents benefit from more extraction capacity.
- First increase `NUM_EXTRACTION_WORKERS` and `CONTENT_EXTRACTION_PARALLEL_WORKERS` within a single replica. If CPU is saturated, add replicas.
- **GPU variants**: Use the CUDA (NVIDIA) or ROCm (AMD) extractor images for GPU-accelerated OCR and document processing.

### When to Scale the NER Service

The NER (Named Entity Recognition) service runs ML models to identify entities in extracted text. Scale it when:

- **NER processing queue is growing**: Check the work queue for a backlog of `ner` work items.
- **GPU variants**: The NER service benefits significantly from GPU acceleration. Use CUDA or ROCm images for production deployments with large file estates.
- One NER replica per GPU is a good starting point.

### When to Scale the API Service

The API service handles HTTP requests, authentication, and proxies to other services. Scale it when:

- **High concurrent user load**: Many simultaneous MCP connections or dashboard users.
- **Search response times degrade**: Under heavy search load, additional API replicas behind a load balancer distribute query execution.
- The API service is stateless and can be scaled horizontally without coordination.
