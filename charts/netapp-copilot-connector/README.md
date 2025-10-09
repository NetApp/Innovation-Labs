# NetApp Neo for Microsoft 365 Copilot - Helm Chart

This Helm chart deploys NetApp Neo for Microsoft 365 Copilot on a Kubernetes cluster using a `StatefulSet` for stable, persistent storage.

## Overview

The chart bootstraps a deployment of NetApp Neo, which includes the following Kubernetes resources:
- **StatefulSet**: Manages the connector pod, ensuring stable network identity and storage.
- **PersistentVolumeClaim**: Provides persistent storage for connector data (e.g., database).
- **Service**: Exposes the connector within the cluster on a stable endpoint.
- **Secret**: Securely stores sensitive credentials like Microsoft Graph API keys and the NetApp license.
- **ConfigMap**: Manages non-sensitive environment variables and configuration.
- **Ingress**: (Optional) Manages external access to the connector service.

## Prerequisites

- Kubernetes cluster (v1.19+ recommended)
- Helm package manager (v3+)
- A default StorageClass configured in your cluster for PersistentVolume provisioning.

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
helm install netapp-connector innovation-labs/netapp-connector --version 26.10.3 \
  --namespace netapp-connector \
  --create-namespace \
  --set main.credentials.MS_GRAPH_CLIENT_ID="<your-graph-client-id>" \
  --set main.credentials.MS_GRAPH_CLIENT_SECRET="<your-graph-client-secret>" \
  --set main.credentials.MS_GRAPH_TENANT_ID="<your-graph-tenant-id>" \
  --set main.credentials.NETAPP_CONNECTOR_LICENSE="<your-license-key>"
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

      # --- Optional Ingress Configuration ---
      ingress:
        enabled: true
        host: "connector.your-domain.com"
        # className: "nginx" # Uncomment and set your IngressClass if needed
        tls:
          - secretName: my-connector-tls-secret
            hosts:
              - connector.your-domain.com
    ```

    > [!WARNING]
    > Do not commit `my-values.yaml` with plain-text secrets to a public version control repository. Use a secret management tool like Azure Key Vault, HashiCorp Vault, or SOPS for handling sensitive data in production.

2.  Install the chart using your custom values file:

    ```sh
    helm install netapp-connector innovation-labs/netapp-connector --version 26.10.3 \
      --namespace netapp-connector \
      --create-namespace \
      -f my-values.yaml
    ```

> [!IMPORTANT]
> The connector will not start correctly without the four mandatory `main.credentials` values being set, regardless of the installation method.

## Upgrading the Chart

To upgrade an existing release, use `helm upgrade`. The `--reuse-values` flag is recommended to preserve your existing configuration, including secrets. You can then override specific values, like the image tag.

```sh
# 1. Update your local chart repository
helm repo update

# 2. Upgrade the release to a new version (e.g., 2.2.5)
helm upgrade netapp-connector innovation-labs/netapp-connector \
  --namespace netapp-connector \
  --reuse-values \
  --set main.image.tag="2.2.5"
```

## Uninstallation

To uninstall and delete the `netapp-connector` release:

```sh
helm uninstall netapp-connector --namespace netapp-connector
```

> [!NOTE]
> This command removes the StatefulSet, Service, and other resources but **does not delete the PersistentVolumeClaim (PVC)**. Your data will be preserved. To permanently delete all data, you must manually delete the PVC.

## Configuration Parameters

The following table lists the configurable parameters of NetApp Neo chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `main.name` | The base name for all created resources. | `netapp-connector-main` |
| `main.replicaCount` | Number of connector pods to run. Only 1 is supported. | `1` |
| `main.image.repository` | The container image repository. | `ghcr.io/netapp/netapp-copilot-connector` |
| `main.image.tag` | The container image tag. If empty, defaults to the chart's `appVersion`. | `""` |
| `main.image.pullPolicy` | The image pull policy. | `Always` |
| `main.service.type` | The type of Kubernetes service to create. | `ClusterIP` |
| `main.service.port` | The port exposed by the service and container. | `8080` |
| `main.ingress.enabled` | If true, create an Ingress resource. | `false` |
| `main.ingress.host` | The hostname for the Ingress rule. Required if Ingress is enabled. | `nil` |
| `main.ingress.path` | The path for the Ingress rule. | `/` |
| `main.ingress.pathType` | The path type for the Ingress rule (`Prefix`, `Exact`, `ImplementationSpecific`). | `Prefix` |
| `main.ingress.className` | The `ingressClassName` to associate with the Ingress. | `""` |
| `main.ingress.tls` | Ingress TLS configuration (list of objects with `secretName` and `hosts`). | `[]` |
| `main.persistence.enabled` | If true, create a `PersistentVolumeClaim`. | `true` |
| `main.persistence.accessMode` | The access mode for the PVC. | `ReadWriteOnce` |
| `main.persistence.size` | The size of the persistent volume. | `1Gi` |
| `main.persistence.mountPath` | The path inside the container where the volume is mounted. | `/app/data` |
| `main.env.*` | Non-sensitive environment variables. See `values.yaml` for all options. | (various) |
| `main.credentials.*` | Sensitive credentials stored in a Secret. **Must be provided by the user.** | (placeholders) |

---
For more information, see the official [Helm documentation](https://helm.sh/docs/) and [Kubernetes documentation](https://kubernetes.io/docs/home/).
