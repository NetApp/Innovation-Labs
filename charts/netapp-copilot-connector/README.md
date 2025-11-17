# NetApp Neo for Microsoft 365 Copilot - Helm Chart

This Helm chart deploys NetApp Neo for Microsoft 365 Copilot on a Kubernetes cluster using `Deployment` resources for scalable application management.

## Overview

The chart bootstraps a deployment of NetApp Neo, which includes the following Kubernetes resources:
- **Deployments**: Manages both the backend connector and UI pods with configurable replicas and rolling updates.
- **Services**: Exposes the connector and UI within the cluster on stable endpoints.
- **Secret**: Securely stores sensitive credentials like Microsoft Graph API keys, NetApp license, and database connection details.
- **ConfigMaps**: Manages non-sensitive environment variables, configuration, and nginx proxy settings for the UI.
- **Ingress**: (Optional) Manages external access to both the connector and UI services.

## Architecture

The chart deploys two main components:

1. **Backend Connector** (`netapp-connector-main`): The core API service that interfaces with Microsoft Graph and your data sources.
2. **UI** (`netapp-connector-ui`): A web interface that communicates with the backend API through an nginx reverse proxy.

The UI automatically proxies API requests to `/api/*` to the backend service, providing seamless communication between components.

## Prerequisites

- Kubernetes cluster (v1.19+ recommended)
- Helm package manager (v3+)
- External database (PostgreSQL or MySQL) for connector data storage

## Installation Guide

### 1. Add Helm Repository

First, add the NetApp Innovation Labs repository to your Helm client.

```sh
helm repo add innovation-labs https://netapp.github.io/Innovation-Labs/
```

### 2. Install the Chart

There are two primary methods for installing the chart: using command-line flags (ideal for testing) or a custom values file (recommended for production).

#### Method 1: Using Command-Line Flags (for Development)

For quick tests, you can pass parameters directly using the `--set` flag.

```sh
helm install netapp-connector innovation-labs/netapp-connector --version 25.11.2 \
  --namespace netapp-connector \
  --create-namespace \
  --set main.credentials.MS_GRAPH_CLIENT_ID="<your-graph-client-id>" \
  --set main.credentials.MS_GRAPH_CLIENT_SECRET="<your-graph-client-secret>" \
  --set main.credentials.MS_GRAPH_TENANT_ID="<your-graph-tenant-id>" \
  --set main.credentials.NETAPP_CONNECTOR_LICENSE="<your-license-key>" \
  --set main.env.DB_TYPE="postgres" \
  --set main.env.DATABASE_URL="postgresql://user:password@hostname:5432/database"
```

#### Method 2: Using a Custom Values File (Recommended for Production)

For production environments, it is highly recommended to use a custom `values.yaml` file to manage your configuration. This makes your deployment more readable, repeatable, and easier to manage in version control.

1.  Create a file named `my-values.yaml` with your configuration:

    ```yaml
    # my-values.yaml
    main:
      # --- Required Credentials ---
      credentials:
        MS_GRAPH_CLIENT_ID: "<your-graph-client-id>"
        MS_GRAPH_CLIENT_SECRET: "<your-graph-client-secret>"
        MS_GRAPH_TENANT_ID: "<your-graph-tenant-id>"
        NETAPP_CONNECTOR_LICENSE: "<your-license-key>"

      # --- Database Configuration ---
      env:
        DB_TYPE: "postgres"  # or "mysql"
        DATABASE_URL: "postgresql://user:password@hostname:5432/database"

      # --- Optional Backend Ingress Configuration ---
      ingress:
        enabled: true
        host: "api.connector.your-domain.com"
        className: "nginx"
        tls:
          - secretName: connector-api-tls-secret
            hosts:
              - api.connector.your-domain.com

    ui:
      # --- Optional UI Ingress Configuration ---
      ingress:
        enabled: true
        host: "connector.your-domain.com"
        className: "nginx"
        tls:
          - secretName: connector-ui-tls-secret
            hosts:
              - connector.your-domain.com
    ```

    > [!WARNING]
    > Do not commit `my-values.yaml` with plain-text secrets to a public version control repository. Use a secret management tool like Azure Key Vault, HashiCorp Vault, or SOPS for handling sensitive data in production.

2.  Install the chart using your custom values file:

    ```sh
    helm install netapp-connector innovation-labs/netapp-connector --version 25.11.2 \
      --namespace netapp-connector \
      --create-namespace \
      -f my-values.yaml
    ```

> [!IMPORTANT]
> The connector requires the following mandatory values to start correctly:
> - `main.credentials.MS_GRAPH_CLIENT_ID`
> - `main.credentials.MS_GRAPH_CLIENT_SECRET` 
> - `main.credentials.MS_GRAPH_TENANT_ID`
> - `main.credentials.NETAPP_CONNECTOR_LICENSE`
> - `main.env.DATABASE_URL` (connection string to your external database)

## Database Setup

The connector requires an external database (PostgreSQL or MySQL) for storing connector data. Ensure your database is accessible from the Kubernetes cluster and configure the connection string in the `DATABASE_URL` parameter.

### PostgreSQL Example:

```
postgresql://username:password@hostname:5432/database_name
```

### MySQL Example:

```
mysql://username:password@hostname:3306/database_name
```

## Accessing the Application

After installation, you can access the application in several ways:

### Option 1: Port Forwarding (Development)

Forward the UI service port to your local machine:

```sh
kubectl port-forward -n netapp-connector svc/netapp-connector-ui 8080:80
```

Then access the UI at `http://localhost:8080`

### Option 2: Ingress (Production)

Enable Ingress in your `values.yaml` to expose the UI externally. The UI will automatically proxy API requests to the backend service.

```yaml
ui:
  ingress:
    enabled: true
    host: "connector.your-domain.com"
    className: "nginx"
```

## Upgrading the Chart

To upgrade an existing release, use `helm upgrade`. The `--reuse-values` flag is recommended to preserve your existing configuration, including secrets. You can then override specific values, like the image tag.

```sh
# 1. Update your local chart repository
helm repo update

# 2. Upgrade the release to a new version
helm upgrade netapp-connector innovation-labs/netapp-connector \
  --namespace netapp-connector \
  --reuse-values \
  --set main.image.tag="3.0.5" \
  --set ui.image.tag="3.0.5"
```

## Uninstallation

To uninstall and delete the `netapp-connector` release:

```sh
helm uninstall netapp-connector --namespace netapp-connector
```

> [!NOTE]
> This command removes the Deployments, Services, and other Kubernetes resources. Your external database data will remain intact as it's managed separately from the Helm chart.

## Configuration Parameters

### Backend (Main) Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `main.name` | The base name for backend resources. | `netapp-connector-main` |
| `main.replicaCount` | Number of backend connector pods to run. | `1` |
| `main.image.repository` | The backend container image repository. | `ghcr.io/netapp/netapp-copilot-connector` |
| `main.image.tag` | The backend container image tag. If empty, defaults to the chart's `appVersion`. | `""` |
| `main.image.pullPolicy` | The image pull policy. | `Always` |
| `main.service.type` | The type of Kubernetes service to create for backend. | `ClusterIP` |
| `main.service.port` | The port exposed by the backend service and container. | `8080` |
| `main.ingress.enabled` | If true, create an Ingress resource for the backend API. | `false` |
| `main.ingress.host` | The hostname for the backend Ingress rule. | `nil` |
| `main.ingress.path` | The path for the backend Ingress rule. | `/` |
| `main.ingress.pathType` | The path type for the Ingress rule. | `Prefix` |
| `main.ingress.className` | The `ingressClassName` to associate with the Ingress. | `""` |
| `main.ingress.tls` | Ingress TLS configuration. | `[]` |
| `main.env.PORT` | The port the backend application runs on. | `8080` |
| `main.env.PYTHONUNBUFFERED` | Python unbuffered output. | `1` |
| `main.env.DB_TYPE` | Database type (`postgres` or `mysql`). | `postgres` |
| `main.env.DATABASE_URL` | Database connection URL. **Must be provided by the user.** | `postgresql://postgres:neodbsecret@neodb:5432/neodb` |
| `main.env.HTTPS_PROXY` | HTTPS proxy configuration. | `""` |
| `main.env.PROXY_USERNAME` | Proxy username if authentication is required. | `""` |
| `main.env.PROXY_PASSWORD` | Proxy password if authentication is required. | `""` |
| `main.env.GRAPH_VERIFY_SSL` | Whether to verify SSL certificates for Microsoft Graph calls. | `""` |
| `main.env.SSL_CERT_FILE` | Custom SSL certificate file content. | `""` |
| `main.env.SSL_CERT_FILE_PATH` | Path to SSL certificate file. | `""` |
| `main.env.GRAPH_TIMEOUT` | Timeout for Microsoft Graph API calls. | `""` |
| `main.credentials.MS_GRAPH_CONNECTOR_ID` | Microsoft Graph connector ID. | `netappconnector` |
| `main.credentials.MS_GRAPH_CONNECTOR_DESCRIPTION` | Description of the connector. | `(default description)` |
| `main.credentials.MS_GRAPH_CLIENT_ID` | Microsoft Graph client ID. **Required.** | `tobeset` |
| `main.credentials.MS_GRAPH_CLIENT_SECRET` | Microsoft Graph client secret. **Required.** | `tobeset` |
| `main.credentials.MS_GRAPH_TENANT_ID` | Microsoft Graph tenant ID. **Required.** | `tobeset` |
| `main.credentials.NETAPP_CONNECTOR_LICENSE` | NetApp connector license key. **Required.** | `tobeset` |

### UI Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ui.name` | The base name for UI resources. | `netapp-connector-ui` |
| `ui.replicaCount` | Number of UI pods to run. | `1` |
| `ui.image.repository` | The UI container image repository. | `ghcr.io/beezy-dev/neo-ui-framework` |
| `ui.image.tag` | The UI container image tag. | `3.0.4` |
| `ui.image.pullPolicy` | The image pull policy. | `Always` |
| `ui.service.type` | The type of Kubernetes service to create for UI. | `ClusterIP` |
| `ui.service.port` | The port exposed by the UI service. | `80` |
| `ui.ingress.enabled` | If true, create an Ingress resource for the UI. | `false` |
| `ui.ingress.host` | The hostname for the UI Ingress rule. | `nil` |
| `ui.ingress.path` | The path for the UI Ingress rule. | `/` |
| `ui.ingress.pathType` | The path type for the Ingress rule. | `Prefix` |
| `ui.ingress.className` | The `ingressClassName` to associate with the Ingress. | `""` |
| `ui.ingress.tls` | Ingress TLS configuration. | `[]` |
| `ui.env.PORT` | The port the UI nginx server runs on. | `80` |

## Networking Architecture

The chart creates the following networking topology:

```
┌─────────────────┐
│   External      │
│    Access       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────────┐
│   UI Ingress    │     │  API Ingress     │
│   (Optional)    │     │   (Optional)     │
└────────┬────────┘     └────────┬─────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│   UI Service    │     │  Main Service    │
│   (ClusterIP)   │     │   (ClusterIP)    │
│   Port: 80      │     │   Port: 8080     │
└────────┬────────┘     └────────┬─────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│   UI Pod(s)     │────▶│  Backend Pod(s)  │
│   (nginx)       │     │   (Python API)   │
│   /api/* proxy  │     │                  │
└─────────────────┘     └──────────┬───────┘
                                   │
                                   ▼
                        ┌──────────────────┐
                        │  External DB     │
                        │  (Postgres/MySQL)│
                        └──────────────────┘
```

The UI includes an nginx reverse proxy that automatically forwards requests from `/api/*` to the backend service at `http://netapp-connector-main:8080`, providing seamless API communication.

## Troubleshooting

### Check Pod Status

```sh
kubectl get pods -n netapp-connector
```

### View Backend Logs

```sh
kubectl logs -n netapp-connector -l component=netapp-connector-main -f
```

### View UI Logs

```sh
kubectl logs -n netapp-connector -l component=netapp-connector-ui -f
```

### Test Backend Connectivity from UI Pod

```sh
kubectl exec -n netapp-connector -it deployment/netapp-connector-ui -- curl http://netapp-connector-main:8080/health
```

### Verify Database Connection

Ensure your database is reachable from the cluster and the connection string is correct:

```sh
kubectl exec -n netapp-connector -it deployment/netapp-connector-main -- env | grep DATABASE_URL
```

---
For more information, see the official [Helm documentation](https://helm.sh/docs/) and [Kubernetes documentation](https://kubernetes.io/docs/home/).
