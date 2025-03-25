# NetApp Copilot Connector Helm Chart

This Helm chart deploys the NetApp Copilot Connector on Kubernetes, providing a scalable and manageable way to run the connector in a Kubernetes environment.

Please note that this chart is currently in alpha and may require additional configuration and testing.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (if persistence is enabled)
- Access to the NetApp Copilot Connector container image

## Getting Started

### Add the Helm Repository

```bash
# Add the repository (if hosted in a Helm repository)
# helm repo add netapp-repo https://charts.netapp.com
# helm repo update
```

### Installing the Chart

To install the chart with the release name `my-connector`:

```bash
# Create a values file with your configuration
cat > my-values.yaml << EOF
config:
  jwtSecretKey: "your-jwt-secret-key"
  netappConnectorLicense: "your-license-key"

# Enable Microsoft Graph integration if needed
msGraph:
  enabled: true
  clientId: "your-ms-graph-client-id"
  clientSecret: "your-ms-graph-client-secret"
  tenantId: "your-ms-graph-tenant-id"
EOF

# Install the chart
helm install my-connector ./netapp-copilot-connector -f my-values.yaml
```

### Uninstalling the Chart

To uninstall/delete the `my-connector` deployment:

```bash
helm uninstall my-connector
```

## Configuration

The following table lists the configurable parameters of the NetApp Copilot Connector chart and their default values.

| Parameter                                    | Description                                              | Default                                         |
| -------------------------------------------- | -------------------------------------------------------- | ----------------------------------------------- |
| `replicaCount`                               | Number of replicas                                       | `1`                                             |
| `image.repository`                           | Image repository                                         | `ghcr.io/netapp/netapp-copilot-connector-gen-2` |
| `image.pullPolicy`                           | Image pull policy                                        | `IfNotPresent`                                  |
| `image.tag`                                  | Image tag                                                | `""` (defaults to chart appVersion)             |
| `imagePullSecrets`                           | Image pull secrets                                       | `[]`                                            |
| `nameOverride`                               | Override the name of the chart                           | `""`                                            |
| `fullnameOverride`                           | Override the full name of the chart                      | `""`                                            |
| `serviceAccount.create`                      | Create a service account                                 | `true`                                          |
| `serviceAccount.annotations`                 | Service account annotations                              | `{}`                                            |
| `serviceAccount.name`                        | Service account name                                     | `""`                                            |
| `podAnnotations`                             | Pod annotations                                          | `{}`                                            |
| `podSecurityContext`                         | Pod security context                                     | `{ fsGroup: 1000 }`                             |
| `securityContext`                            | Container security context                               | See values.yaml                                 |
| `service.type`                               | Service type                                             | `ClusterIP`                                     |
| `service.port`                               | Service port                                             | `8080`                                          |
| `ingress.enabled`                            | Enable ingress                                           | `false`                                         |
| `ingress.className`                          | Ingress class name                                       | `""`                                            |
| `ingress.annotations`                        | Ingress annotations                                      | `{}`                                            |
| `ingress.hosts`                              | Ingress hosts                                            | See values.yaml                                 |
| `ingress.tls`                                | Ingress TLS configuration                                | `[]`                                            |
| `resources`                                  | Resource requests and limits                             | See values.yaml                                 |
| `autoscaling.enabled`                        | Enable autoscaling                                       | `false`                                         |
| `autoscaling.minReplicas`                    | Minimum replicas                                         | `1`                                             |
| `autoscaling.maxReplicas`                    | Maximum replicas                                         | `3`                                             |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization                                   | `80`                                            |
| `persistence.enabled`                        | Enable persistence                                       | `true`                                          |
| `persistence.storageClass`                   | Storage class                                            | `""`                                            |
| `persistence.accessMode`                     | Access mode                                              | `ReadWriteOnce`                                 |
| `persistence.size`                           | Size                                                     | `10Gi`                                          |
| `persistence.annotations`                    | Persistence annotations                                  | `{}`                                            |
| `persistence.existingClaim`                  | Existing claim                                           | `""`                                            |
| `config.jwtSecretKey`                        | JWT secret key                                           | `""`                                            |
| `config.netappConnectorLicense`              | NetApp connector license key                             | `""`                                            |
| `config.port`                                | Application port                                         | `8080`                                          |
| `config.accessTokenExpireMinutes`            | Access token expiration time                             | `60`                                            |
| `config.logLevel`                            | Log level                                                | `"INFO"`                                        |
| `config.dbPath`                              | Database path                                            | `"/app/data/connector.db"`                      |
| `config.maxFileSize`                         | Maximum file size                                        | `1000000000`                                    |
| `config.minFileSize`                         | Minimum file size                                        | `0`                                             |
| `msGraph.enabled`                            | Enable Microsoft Graph integration                       | `false`                                         |
| `msGraph.clientId`                           | Microsoft Graph client ID                                | `""`                                            |
| `msGraph.clientSecret`                       | Microsoft Graph client secret                            | `""`                                            |
| `msGraph.tenantId`                           | Microsoft Graph tenant ID                                | `""`                                            |
| `msGraph.connectorId`                        | Microsoft Graph connector ID                             | `"netappcopilot"`                               |
| `msGraph.connectorName`                      | Microsoft Graph connector name                           | `"NetApp Connector"`                            |
| `msGraph.connectorDescription`               | Microsoft Graph connector description                    | `"NetApp Connector for Microsoft 365 Copilot"`  |
| `extraEnv`                                   | Additional environment variables                         | `[]`                                            |
| `extraEnvFrom`                               | Additional environment variables from secrets/configmaps | `[]`                                            |
| `extraVolumes`                               | Additional volumes                                       | `[]`                                            |
| `extraVolumeMounts`                          | Additional volume mounts                                 | `[]`                                            |
| `nodeSelector`                               | Node selector                                            | `{}`                                            |
| `tolerations`                                | Tolerations                                              | `[]`                                            |
| `affinity`                                   | Affinity                                                 | `{}`                                            |

## Persistence

The NetApp Copilot Connector stores its data at `/app/data` in the container. The chart mounts a Persistent Volume at this location when persistence is enabled. The PVC is created using the configured parameters.

## Security

The chart includes security contexts for both the pod and the container to ensure proper permissions. The connector runs as a non-root user (UID 1000) by default.

## Microsoft Graph Integration

To enable Microsoft Graph integration, set `msGraph.enabled` to `true` and provide the required credentials. These will be stored as Kubernetes secrets.

## Additional Resources

- [NetApp Copilot Connector Documentation](https://netapp.com/documentation)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Helm Documentation](https://helm.sh/docs/)
