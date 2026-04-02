
# Deploy using Docker/Podman

This guide walks through deploying NetApp Project Neo v4 using Docker or Podman Compose. The deployment includes six services:

- `postgres` -- PostgreSQL 17 shared database
- `api` -- FastAPI service (HTTP API + MCP transport) on port `8000`
- `worker` -- Background processing (crawling, upload, NER orchestration)
- `extractor` -- Content extraction (MarkItDown, Docling, VLM)
- `ner` -- GLiNER2 Named Entity Recognition
- `neoui` -- Web management console on port `8081`
- `nginx` -- An optional load balancer for scaled deployment

## Prerequisites

::: details Docker
- Docker installed on your system. You can download Docker from the [official Docker website](https://www.docker.com/get-started/).
- Docker Compose installed. You can find installation instructions on the [Docker Compose installation page](https://docs.docker.com/compose/install/).
:::

::: details Podman
- Podman installed on your system. You can download Podman from the [official Podman website](https://podman.io/getting-started/installation).
- Podman Compose installed. You can install it using the [Podman Compose installation instructions](https://github.com/containers/podman-compose).
- Linux distribution, like RHEL-based, might not deploy all the podman packages for advanced networking configuration such as `podman-plugins` and `containernetworking-plugins`.

> [!WARNING]
> The main difference between ```docker``` and ```podman``` is that ```podman``` requires a ```sudo``` prefix for privileged containers. Docker's daemon already runs containers in a privileged mode.
:::

- Sufficient system resources to run NetApp Neo. Refer to the [Sizing Guide](/projects/neo/core/d-sizing.md) in the Deployment section for recommended specifications.
- ```cifs-utils``` package deployed on the Linux host (required for SMB share mounting by the extractor service).
- ```SELinux``` contexts may require adjustments based on your specific Linux host security profile.

## Deployment Guide

> [!TIP]
> Both `docker-compose.yml` and `.env` files provides a comprehensive inline documentation for every environment variable, GPU configuration options.

### Docker Compose file

<!-- Download ```docker-compose.yml``` from the [latest GitHub release](https://github.com/NetApp/Innovation-Labs/releases) into a directory of your choice: -->

Create a directory, e.g., `neov4`
```BASH
mkdir neov4 && cd neov4
``` 

The following Docker Compose file can be copied as `docker-compose.yaml`   

<<< ../examples/docker-compose.example.yaml 

### Environment file (`.env`)

Aside from the versioning and database paramters, Neo services can be configured after startup either via the UI or the API. Here are the parameters to be modified from the example `.env` file:

```bash
# Neo container image versioning
NEO_VERSION=4.0.3p7
NUI_VERSION=3.2.2

## Database Settings (required)
# Modify accordingly to your preferences
# CAN NOT BE MODIFIED AFTER FIRST RUN.
POSTGRES_HNAME=postgres
POSTGRES_USER=neo
POSTGRES_PASSWORD=neo_password
POSTGRES_DB=neo_connector
POSTGRES_PORT=5432
```

Once you have the above parameters squared out, copy this `.env` file in the same directory where you have created the `docker-compose.yaml` file, and modify the versioning and database parameters accordingly to your preferences:

<<< ../examples/env 

> [!TIP]
> The usage of [Docker/Podman Secrets](https://docs.docker.com/compose/how-tos/use-secrets/) is recommended for production deployments to avoid storing credentials in plain text.

### Start the containers

::: code-group

```BASH [Docker]
docker compose up -d --build
docker compose ps

Expected output:
NAME            IMAGE                                       STATUS                    PORTS
neo-postgres    postgres:17                                 Up 30 seconds (healthy)
api-1           neo-api                                     Up 25 seconds (healthy)   0.0.0.0:8000->8000/tcp
extractor-1     neo-extractor                               Up 28 seconds (healthy)
ner-1           neo-ner                                     Up 28 seconds (healthy)
worker-1        neo-worker                                  Up 20 seconds (healthy)
neoui           ghcr.io/beezy-dev/neo-ui-framework:3.2.2   Up 18 seconds             0.0.0.0:8081->80/tcp

View logs:
docker compose logs -f
```

```BASH [Podman]
sudo podman compose up -d --build
sudo podman compose ps

Expected output:
NAME            IMAGE                                       STATUS                    PORTS
neo-postgres    postgres:17                                 Up 30 seconds (healthy)
api-1           neo-api                                     Up 25 seconds (healthy)   0.0.0.0:8000->8000/tcp
extractor-1     neo-extractor                               Up 28 seconds (healthy)
ner-1           neo-ner                                     Up 28 seconds (healthy)
worker-1        neo-worker                                  Up 20 seconds (healthy)
neoui           ghcr.io/beezy-dev/neo-ui-framework:3.2.2   Up 18 seconds             0.0.0.0:8081->80/tcp

View logs:
sudo podman compose logs -f
```
:::

> [!TIP]
> The NER service takes up to 2-3 minutes to start on first launch while it downloads the GLiNER2 model. The worker service waits for NER to become healthy before starting.

You should see logs indicating that the API service has started in setup mode:

```log
api-1  | INFO     | app.main:lifespan - Starting up application...
api-1  | INFO     | app.main:lifespan - Setup mode: Skipping license validation and Graph initialization
api-1  | INFO     | app.main:lifespan - Complete setup via /api/v1/setup endpoints to enable full functionality
api-1  | INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

### Scale services independently

Neo v4 supports independent scaling of worker, extractor, and NER services:

::: code-group

```BASH [Docker]
# Scale workers for higher crawling throughput
docker compose up -d --scale worker=3

# Scale extractors for faster document processing
docker compose up -d --scale extractor=5 --scale ner=2
```

```BASH [Podman]
sudo podman compose up -d --scale worker=3
sudo podman compose up -d --scale extractor=5 --scale ner=2
```
:::

### Configure

#### via GUI

Neo Console is available at ```http://your-host:8081``` and will present the setup wizard on first launch.

Go to **Settings** and select the **Neo Core** tab to begin configuration.

1. Enter a valid license key and save.
2. Optionally configure Microsoft Graph, SSL, or proxy settings.
3. Click **Setup Complete** to finalize. This triggers a restart of the services with the configured settings.

Once setup completes, the page displays a status of "Complete" and an **Admin Credentials** button appears with temporary login credentials.

> [!IMPORTANT]
> The temporary password will not be accessible again after you log in. Save it in your password manager or change it immediately in the Users page.

#### via API

Neo can also be configured via the API. The interactive API documentation is available at ```http://your-host:8000/docs```.

**Step 1: Set the license key**

```bash
curl -X POST http://localhost:8000/api/v1/setup/license \
  -H "Content-Type: application/json" \
  -d '{"license_key": "your-license-key"}'
```

**Step 2: (Optional) Configure Microsoft Graph**

```bash
curl -X POST http://localhost:8000/api/v1/setup/graph \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "your-tenant-id",
    "client_id": "your-client-id",
    "client_secret": "your-client-secret"
  }'
```

**Step 3: Complete setup**

```bash
curl -X POST http://localhost:8000/api/v1/setup/complete
```

### GPU Acceleration (optional)

The **ner** and **extractor** services support GPU acceleration for faster inference.

::: details NVIDIA GPU
Add the following to the ```ner``` and/or ```extractor``` service in your ```docker-compose.yml```:

```yaml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

Requires [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed on the host.
:::

::: details AMD ROCm GPU
Add the following to the ```ner``` and/or ```extractor``` service in your ```docker-compose.yml```:

```yaml
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    group_add:
      - video
      - render
    environment:
      NER_DEVICE: cuda  # ROCm uses the CUDA compatibility layer
```

Requires ROCm drivers installed on the host.
:::

## Troubleshooting

### PostgreSQL

Check if the database was created:

::: code-group

```BASH [Docker]
docker exec -it neo-postgres psql -h localhost -U neo -d neo_connector -c '\l'
```

```BASH [Podman]
sudo podman exec -it neo-postgres psql -h localhost -U neo -d neo_connector -c '\l'
```
:::

Expected output should include ```neo_connector``` in the database list.

### API Service

::: code-group

```BASH [Docker]
docker compose logs -f api
```

```BASH [Podman]
sudo podman compose logs -f api
```
:::

Check the health endpoint:
```bash
curl http://localhost:8000/health
```

### Worker Service

::: code-group

```BASH [Docker]
docker compose logs -f worker
```

```BASH [Podman]
sudo podman compose logs -f worker
```
:::

> [!TIP]
> The worker requires ```SYS_ADMIN``` and ```DAC_READ_SEARCH``` capabilities and ```apparmor:unconfined``` security option. If the worker fails to start, verify that your container runtime supports these settings.

### Extractor Service

::: code-group

```BASH [Docker]
docker compose logs -f extractor
```

```BASH [Podman]
sudo podman compose logs -f extractor
```
:::

> [!TIP]
> The extractor runs in privileged mode to support NFS/CIFS mounting inside the container. If mounting fails, verify that ```cifs-utils``` is installed on the host.

### NER Service

::: code-group

```BASH [Docker]
docker compose logs -f ner
```

```BASH [Podman]
sudo podman compose logs -f ner
```
:::

The NER service downloads the GLiNER2 model on first startup. If it fails, check network connectivity and disk space.

### Neo UI

::: code-group

```BASH [Docker]
docker logs -f neoui
```

```BASH [Podman]
sudo podman logs -f neoui
```
:::

Check the browser developer console for additional error messages.

## Next steps

This concludes the steps to deploy NetApp Neo using Docker/Podman Compose. For more advanced configurations and management options, refer to the [Management](/projects/neo/core/management.md) section of the documentation.
