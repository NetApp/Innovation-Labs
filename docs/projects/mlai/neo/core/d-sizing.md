# Sizing Guide

NetApp Project Neo v4 is composed of four microservices (API, Worker, Extractor, NER) plus a PostgreSQL database. Resource requirements depend on the volume of files being indexed and the processing throughput needed.

## Deployment Profiles

| Profile | Files | CPU | RAM | GPU | Storage |
|---------|-------|-----|-----|-----|---------|
| Small | <50K | 4 vCPU | 8 GB | Optional | 20 GB |
| Medium | 50K-500K | 8 vCPU | 16 GB | Recommended | 50 GB |
| Large | 500K-2M | 16 vCPU | 32 GB | Recommended | 100 GB |
| Enterprise | 2M+ | 32+ vCPU | 64+ GB | Required | 200+ GB |

The above figures represent the total resources across all services. See the per-service breakdown below for how to distribute resources.

## Per-Service Resource Breakdown

### API Service

Lightweight HTTP service handling REST requests, authentication, and routing. Minimal resource requirements.

- CPU: 1-2 vCPU
- RAM: 1-2 GB
- GPU: Not required
- I/O: Low

### Worker Service

Handles file discovery, SMB crawling, scheduling, and Microsoft Graph uploads. CPU and network intensive during crawl operations.

- CPU: 2-8 vCPU (scales with concurrent crawl jobs)
- RAM: 2-8 GB
- GPU: Not required
- I/O: High network throughput (SMB + Graph API)

### Extractor Service

Performs document content extraction (PDF, Office, images). Heavily benefits from GPU acceleration for OCR and document layout analysis.

- CPU: 2-8 vCPU
- RAM: 4-16 GB
- GPU: Recommended (CUDA for NVIDIA, ROCm for AMD)
- I/O: Moderate

### NER Service

Runs Named Entity Recognition models against extracted text. GPU-intensive for inference workloads.

- CPU: 2-4 vCPU
- RAM: 4-8 GB
- GPU: Recommended for production workloads
- I/O: Low

### PostgreSQL Database

Primary data store for metadata, extracted content, search indexes, and ACLs. I/O intensive, especially during large crawl operations.

- CPU: 2-4 vCPU
- RAM: 4-16 GB
- GPU: Not required
- I/O: High (SSD strongly recommended)

## Database Sizing

The database requirements depend on the size of your source data and the number of indexed documents:

- **General rule**: ~2 GB of database storage per 100 GB of source documents indexed (approximately 2% of source data size)
- **With full-text content storage**: Database size may increase to 5-10% of source data size
- **NER results**: Add approximately 10-20% to the base database size if NER is enabled

Ensure your PostgreSQL instance has adequate disk I/O performance. SSDs are strongly recommended for production deployments.

## GPU Variants

Neo provides GPU-accelerated container variants for the Extractor and NER services:

- **CUDA** (NVIDIA): Images tagged with `-cuda` suffix
- **ROCm** (AMD): Images tagged with `-rocm` suffix

GPU acceleration significantly improves extraction and NER throughput. For deployments processing more than 50K files, GPU is recommended. For Enterprise deployments, GPU is required for acceptable processing times.

## Performance Benchmarking

For detailed performance benchmarks and tuning guidance, see [Performance](./m-performance.md).
