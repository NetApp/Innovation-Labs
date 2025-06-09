# NetApp Connector Kubernetes Helm Chart

This directory contains a Helm chart for deploying the NetApp Connector as a single-pod StatefulSet with persistent storage on Kubernetes.

## Overview
- **StatefulSet** ensures the pod always mounts the same persistent volume, suitable for workloads requiring stable storage.
- **PersistentVolumeClaim** is used for data at `/data`, matching the Docker Compose setup.
- **Init Container** initializes data directory permissions before the main app starts.
- **Service** exposes the application on port 8080 inside the cluster (ClusterIP by default).
- **Configurable** via `values.yaml` for image, storage, and environment variables.

## Prerequisites
- A working Kubernetes cluster (v1.18+ recommended)
- [Helm 3](https://helm.sh/) installed

## Installation
1. Clone or copy this repository to your environment.
2. Change to the `k8s` directory:
   ```sh
   cd k8s
   ```

## Setting Mandatory Environment Variables
The connector requires the following four mandatory environment variables to be set for successful operation:

- `NETAPP_CONNECTOR_LICENSE` (your license key)
- `MS_GRAPH_CLIENT_ID` (your Microsoft Graph client ID)
- `MS_GRAPH_CLIENT_SECRET` (your Microsoft Graph client secret)
- `MS_GRAPH_TENANT_ID` (your Microsoft tenant ID)

These variables are set during the installation process using `--set` flags creating a Kubernetes Secret object. The connector will use this secret to access the required credentials.


3. Install the chart (replace `netapp-connector` with your desired release name and namespace):
   ```sh
   helm install netapp-connector \            
    -n netapp-connector --create-namespace . \
    --set main.credentials.MS_GRAPH_CLIENT_ID= \                         
    --set main.credentials.MS_GRAPH_CLIENT_SECRET= \               
    --set main.credentials.MS_GRAPH_TENANT_ID= \                      
    --set main.credentials.NETAPP_CONNECTOR_LICENSE= 
   ```
   This will deploy using the default settings in `values.yaml`.

4. To customize settings (image, storage size, environment variables), edit `values.yaml` or use `--set` flags. For example:
   ```sh
   helm install netapp-connector . \
    -n netapp-connector --create-namespace \
     --set main.credentials.MS_GRAPH_CLIENT_ID=<tbd> \
     --set main.credentials.MS_GRAPH_CLIENT_SECRET=<tbd> \
     --set main.credentials.MS_GRAPH_TENANT_ID=<tbd> \
     --set main.credentials.NETAPP_CONNECTOR_LICENSE=<tbd> \
     --set image.repository=<internal.container.registry>/netapp-connector \
     --set image.tag=2.0.6 \
     --set persistence.size=10Gi
   ```

## Uninstall
To remove the deployment:
```sh
helm uninstall netapp-connector -n netapp-connector
```

## Accessing the Service
By default, the service is internal (ClusterIP). To access externally, modify `values.yaml` to set `service.type` to `NodePort` or `LoadBalancer` as appropriate for your cluster.

## Notes
- The persistent volume will retain data even if the pod is deleted or recreated.
- You may need to configure storage classes or provisioner depending on your Kubernetes environment.
- For advanced configuration (secrets, ingress, etc.), extend the chart as needed.

---
For more information, see the official [Helm documentation](https://helm.sh/docs/) and [Kubernetes documentation](https://kubernetes.io/docs/home/).
