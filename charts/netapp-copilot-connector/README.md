# NetApp Connector for Copilot 365 - Kubernetes Helm Chart

This directory contains a Helm chart for deploying the NetApp Connector as a StatefulSet with persistent storage on Kubernetes.

## Overview
- `StatefulSet` ensures the pod always mounts the same persistent volume, suitable for workloads requiring stable storage.
- `PersistentVolumeClaim` is used for data at `/app/data`.
- `Service` exposes the application on port 8080 inside the cluster (ClusterIP by default).
- **Configurable** via `--set` or `values.yaml` for image, storage, and environment variables.

## Prerequisites
- A working Kubernetes cluster (v1.18+ recommended)
- [Helm 3](https://helm.sh/) installed

## Installation

### Setting Mandatory Environment Variables
The connector requires the following four mandatory environment variables to be set for successful operation:

- `MS_GRAPH_CONNECTOR_ID` (this is the ID of the Microsoft Graph connector - only change if multiple connector instances are used)
- `NETAPP_CONNECTOR_LICENSE` (your license key)
- `MS_GRAPH_CLIENT_ID` (your Microsoft Graph client ID)
- `MS_GRAPH_CLIENT_SECRET` (your Microsoft Graph client secret)
- `MS_GRAPH_TENANT_ID` (your Microsoft tenant ID)

> [!IMPORTANT]
> Without these variables, the connector will not function properly.
> To customize these variables, use `--set` flags (for Helm Repository) or the `values.yaml` file (for GitHub Releases) as described below.

### Helm Repository
1. Add the Helm repository:
   ```sh
   helm repo add innovation-labs https://netapp.github.io/Innovation-Labs/
   ```
   If you have already added the repository, you can skip this step and update it:
   ```sh
   helm repo update
   ```
1. Check out the chart repository content:
   ```sh
   helm search repo innovation-labs 
   ```
1. Install the chart:
   ```
   helm install netapp-connector innovation-labs/netapp-connector \
      --namespace netapp-connector --create-namespace \
      --set main.credentials.MS_GRAPH_CLIENT_ID="your_graph_client_id" \
      --set main.credentials.MS_GRAPH_CLIENT_SECRET="your_graph_client_secret" \
      --set main.credentials.MS_GRAPH_TENANT_ID="your_graph_tenant_id" \
      --set main.credentials.NETAPP_CONNECTOR_LICENSE="your_license_key"
   ```

### GitHub Releases
1. Download the latest release from the [GitHub Releases page](https://github.com/NetApp/Innovation-Labs/releases).
1. Extract the chart:
   ```sh
   tar -xzf netapp-connector-<version>.tgz
   cd netapp-connector
   ```
1. Install the chart using Helm:
   ```
   helm install netapp-connector . \
      --namespace netapp-connector --create-namespace \
      --set main.credentials.MS_GRAPH_CLIENT_ID="your_graph_client_id" \
      --set main.credentials.MS_GRAPH_CLIENT_SECRET="your_graph_client_secret" \
      --set main.credentials.MS_GRAPH_TENANT_ID="your_graph_tenant_id" \
      --set main.credentials.NETAPP_CONNECTOR_LICENSE="your_license_key"
   ```

## Uninstall
To remove the deployment:
```sh
helm delete netapp-connector --namespace netapp-connector
```

## Accessing the Service
By default, the service is internal (ClusterIP). To access externally, modify `values.yaml` to set `service.type` to `NodePort` or `LoadBalancer` as appropriate for your cluster.

## Notes
- Depending on your reclaim policy:
   - You can delete the `Pod`, `StatefulSet`, and Helm Chart without losing data. Redeploying the chart will reuse the existing `PersistentVolumeClaim`.
   - You may need to manually delete the PersistentVolumeClaim if you want to remove the data and start fresh.
- If no default `StorageClass` is set, you may need to manually provision the `PersistentVolumeClaim`.
- For advanced configuration (secrets, ingress, etc.), extend the chart as needed.

---
For more information, see the official [Helm documentation](https://helm.sh/docs/) and [Kubernetes documentation](https://kubernetes.io/docs/home/).
