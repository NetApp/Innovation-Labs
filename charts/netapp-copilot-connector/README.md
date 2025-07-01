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

> [!NOTE] 
> For deployment with proxy configuration, modify the values of the following parameters: ```HTTPS_PROXY```, ```PROXY_USERNAME```, ```PROXY_PASSWORD```, ```GRAPH_VERIFY_SSL```, ```GRAPH_TIMEOUT```.

## Updating
Let's say that you are currently running the version 2.0.6 and you wish to updat to 2.1.0. 

1. First, you have to update the repo:
   ```sh
   helm repo update
   ```
1. Check your current image version: 
   ```sh 
   kubectl -n netapp-connector get pods netapp-connector-main-0 -o yaml |grep image
   ```
   Expected output: 
   ``` 
    image: ghcr.io/netapp/netapp-copilot-connector:2.0.6
    imagePullPolicy: Always
    image: ghcr.io/netapp/netapp-copilot-connector:2.0.6
    imageID: ghcr.io/netapp/netapp-copilot-connector@sha256:f3f0af7256d0be1bb1f2959a304907f91cd5c6055bb7912449f81558179a236f
   ```
1. Upgrade your helm deployment with **--reuse-values** to avoid losing access to your graph and license keys:
   ```
   helm upgrade netapp-connector innovation-labs/netapp-connector --namespace netapp-connector --reuse-values --set main.image.tag=2.1.0
   ```
   Expected output:
   ```
   Release "netapp-connector" has been upgraded. Happy Helming!
   NAME: netapp-connector
   LAST DEPLOYED: Fri Jun 13 16:32:53 2025
   NAMESPACE: netapp-connector
   STATUS: deployed
   REVISION: 2
   TEST SUITE: None
   ```
1. Check your current image version:
   ```
   kubectl -n netapp-connector get pods netapp-connector-main-0 -o yaml |grep image
    image: ghcr.io/netapp/netapp-copilot-connector:2.1.0
    imagePullPolicy: Always
    image: ghcr.io/netapp/netapp-copilot-connector:2.1.0
    imageID: ghcr.io/netapp/netapp-copilot-connector@sha256:7cb3e00641fe5d75935aefa876ed2d868a2760d3f9ec92cac263e8ef6c84d072
   ```

> [!NOTE] 
> If any new values are added to the helm charts, you can added them after **--reuse-values** like we did for the image version.

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
