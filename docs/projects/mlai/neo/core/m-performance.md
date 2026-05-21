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
| **Database** | Read query throughput and latency |
| **Enumeration** | File discovery and directory scanning performance |
| **Extraction** | Content extraction throughput |
| **ACL Extraction** | ACL/permission resolution throughput |
| **Graph Upload** | Microsoft Graph API upload throughput, including rate-limit detection |

### Metrics Per Stage

Each stage reports:

- **Throughput** (items/second) -- sustained processing rate
- **Average latency** (ms) -- mean time per operation
- **P95 latency** (ms) -- 95th percentile latency
- **Error rate** -- fraction of operations that failed
- **Sample size** -- number of operations measured

### Bottleneck Detection

After all stages complete, the system identifies the stage with the lowest throughput as the pipeline bottleneck and generates tuning recommendations. The auto-tuner suggests parameter adjustments targeting the specific bottleneck stage, such as increasing worker counts, adjusting batch sizes, or modifying rate limits.

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

| Profile | File Estate | Recommended CPU | Recommended RAM |
|---|---|---|---|
| **Small** | < 10K files | 2 cores | 4 GB |
| **Medium** | 10K - 100K files | 4 cores | 8 GB |
| **Large** | 100K - 1M files | 8 cores | 16 GB |
| **Enterprise** | > 1M files | 16+ cores | 32+ GB |

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

Neo exposes a comprehensive set of environment variables for manual tuning. Set them in your Docker Compose file, Kubernetes deployment, or container runtime environment.

Key tuning categories include:

- **Worker concurrency** -- control the number of extraction workers, upload workers, and parallel threads
- **Enumeration** -- adjust directory scanning parallelism and strategies for large file estates
- **Batch sizes** -- optimize database insert and work queue batch sizes for throughput
- **Microsoft Graph rate limiting** -- balance upload speed against API throttling
- **Timeouts** -- configure processing, extraction, and upload timeouts
- **Database** -- adjust connection pool sizes and query timeouts
- **Content extraction** -- set maximum file sizes and content chunking thresholds

Use the sizing API endpoints (`GET /api/v1/monitoring/sizing/parameters`) to retrieve the full list of tunable parameters with descriptions, defaults, and recommended values for your hardware.

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
