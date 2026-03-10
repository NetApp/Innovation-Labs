# Quick Start

This guide will help you get started with deploying NetApp Project Neo using your preferred container platform.

## Choose Your Deployment Method

| Method | Best For | Guide |
|--------|----------|-------|
| **Docker Compose** | Development, small deployments | [Docker Quick Start](./qs-docker.md) |
| **Podman Compose** | RHEL/CentOS environments, rootless containers | [Podman Quick Start](./qs-podman.md) |
| **Kubernetes / Helm** | Production, high availability, auto-scaling | [Kubernetes Quick Start](./qs-kubernetes.md) |

## Architecture Overview

Neo v4 runs as a set of cooperating microservices:

| Service | Role | Port |
|---------|------|------|
| **API** | HTTP API, MCP transport, OAuth | 8000 |
| **Worker** | Background processing, crawling, Graph upload | Internal |
| **Extractor** | Content extraction (MarkItDown, Docling, VLM) | Internal |
| **NER** | Named Entity Recognition (GLiNER2) | Internal |
| **PostgreSQL** | Shared database | Internal |
| **Neo UI** | Web management console | 8081 |

Services can be scaled independently:

```bash
docker compose up -d --scale worker=3 --scale extractor=2
```

## What You'll Need

Before you begin, review the [Prerequisites](./prerequisites.md) to ensure your environment is ready.

## After Deployment

Once deployed, Neo starts in **setup mode**. Complete the initial configuration (license key, optional Microsoft Graph integration) via the web console at `http://your-server:8081` or the API at `http://your-server:8000/docs`.

For detailed configuration options, see the [Configuration Guide](./d-configuration.md).
