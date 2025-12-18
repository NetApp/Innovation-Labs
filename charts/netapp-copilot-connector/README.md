# NetApp Neo for Microsoft 365 Copilot - Helm Chart

This Helm chart deploys NetApp Neo for Microsoft 365 Copilot on a Kubernetes cluster using `Deployment` resources for scalable application management.

> [!NOTE]
> **📖 Comprehensive Documentation Available**: This README provides a quick start guide. For detailed documentation including cloud-specific configurations, best practices, and troubleshooting, see the **[Full Documentation](docs/)**.

## Quick Links

- 📖 **[Complete Documentation](docs/)** - Full documentation with detailed guides
- 🚀 **[Quick Start Guide](docs/getting-started/quick-start.md)** - Get up and running in minutes
- 🏗️ **[Architecture Overview](docs/getting-started/overview.md)** - Understand the components
- ☁️ **Cloud Provider Guides**: [Azure](docs/cloud-providers/azure/deployment.md) | [AWS](docs/cloud-providers/aws/deployment.md) | [GCP](docs/cloud-providers/gcp/deployment.md)
- 🔧 **[Configuration Reference](docs/configuration/values-reference.md)** - All configuration options
- 📈 **[Scaling Guide](docs/operations/scaling.md)** - Production deployment patterns
- 🔍 **[Troubleshooting](docs/operations/troubleshooting.md)** - Common issues and solutions

## Overview

The chart bootstraps a deployment of NetApp Neo, which includes the following Kubernetes resources:
- **Deployments**: Manages both the backend connector and UI pods with configurable replicas and rolling updates.
- **Services**: Exposes the connector and UI within the cluster on stable endpoints.
- **Secrets**: Securely stores sensitive credentials like Microsoft Graph API keys, NetApp license, and database connection details.
- **ConfigMaps**: Provide non-sensitive backend environment variables. The UI now bundles its nginx config, so no ConfigMap mount is required.
- **StatefulSet**: (Optional) Manages PostgreSQL database with persistent storage when enabled.
- **Ingress**: (Optional) Manages external access to both the connector and UI services.

## Architecture

The chart deploys up to three main components:

1. **Backend Connector** (`netapp-connector-main`): The core API service that interfaces with Microsoft Graph and your data sources.
2. **UI** (`netapp-connector-ui`): A web interface that communicates with the backend API through an nginx reverse proxy.
3. **PostgreSQL Database** (`neodb`): (Optional) An integrated PostgreSQL database for connector data storage.

### Key Features

- **Auto-configured Database URL**: When using the built-in PostgreSQL, the `DATABASE_URL` is automatically generated from PostgreSQL settings
- **InitContainer Health Check**: Ensures PostgreSQL is ready before starting the backend connector
- **Nginx Reverse Proxy**: UI automatically proxies API requests from `/api/*` to the backend service
- **Separation of Concerns**: Non-sensitive configuration in ConfigMaps, sensitive data in Secrets
- **Self-contained UI nginx config**: UI image 3.1.0 embeds the nginx template; ConfigMap/volume mounts are no longer needed.
- **Post-install configuration and credential management**: For appVersion ≥3.1.0, Microsoft Graph credentials and licenses are configured through the product UI/API after deployment.

📖 **[Read more about the architecture →](docs/getting-started/overview.md)**

## Prerequisites

- Kubernetes cluster (v1.24+ recommended)
- Helm package manager (v3.8+)
- Database for connector data storage:
  - **Option 1**: Enable the built-in PostgreSQL deployment (`postgresql.enabled: true`)
  - **Option 2**: Use an external database (PostgreSQL or MySQL)
- (Optional) StorageClass for persistent volumes if using the built-in PostgreSQL
- Microsoft Graph API credentials (configured post-installation for v3.1.0+)

📖 **[Complete prerequisites guide →](docs/getting-started/prerequisites.md)**

## Installation Guide

### 1. Add Helm Repository

First, add the NetApp Innovation Labs repository to your Helm client.

```sh
helm repo add innovation-labs https://netapp.github.io/Innovation-Labs/
helm repo update
```

### 2. Install the Chart

There are two primary methods for installing the chart: using command-line flags (ideal for testing) or a custom values file (recommended for production).

> [!TIP]
> Deploying an older appVersion (<3.1.0)? Then use version 25.11.7 of the chart to continue using `--set main.credentials.*` flags to pre-seed Microsoft Graph values.

#### Method 1: Using Command-Line Flags (for Development)

<details>
  <summary> Option A: With Built-in PostgreSQL (Auto-configured)</summary>

```sh
helm install netapp-connector innovation-labs/netapp-connector --version 25.12.1 \
  --namespace netapp-connector \
  --create-namespace \
  --set postgresql.enabled=true \
  --set postgresql.auth.password="your-secure-password" \
  --set postgresql.auth.database="netappconnector"
```

</details>  

<details>
<summary> Option B: With External Database </summary>

```sh
helm install netapp-connector innovation-labs/netapp-connector --version 25.12.1 \
  --namespace netapp-connector \
  --create-namespace \
  --set postgresql.enabled=false \
  --set main.env.DB_TYPE="postgres" \
  --set main.env.DATABASE_URL="postgresql://user:password@external-host:5432/database"
```

</details>


#### Method 2: Using a Custom Values File (Recommended for Production)

For production environments, it is highly recommended to use a custom `values.yaml` file to manage your configuration. This makes your deployment more readable, repeatable, and easier to manage in version control.

##### Create a file named `my-values.yaml` with your configuration:

<details>
<summary>Option A: With Built-in PostgreSQL</summary>

```yaml
# my-values.yaml
# PostgreSQL Database Configuration
postgresql:
  enabled: true
  auth:
    username: postgres
    password: "your-secure-password"
    database: netappconnector
  persistence:
    enabled: true
    storageClass: ""  # Use default StorageClass, or specify "managed-premium" for AKS
    size: 10Gi
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
main:
  # --- Internal Database Configuration ---
  env:
    DATABASE_URL: ""
  # --- Optional Backend Ingress Configuration ---
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "nginx"  # or any relevant value to your environment
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
</details>

<details>
<summary>Option B: With External Database</summary>

```yaml
# my-values.yaml
# Disable built-in PostgreSQL
postgresql:
  enabled: false
main:
  # --- External Database Configuration ---
  env:
    # For PostgreSQL
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.mydomain.com:5432/database_name" # parameter like ?sslmode=require could be added
    # For MySQL
    # DATABASE_URL: "mysql://username:password@hostname:3306/database_name"
  # --- Optional Backend Ingress Configuration ---
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "nginx"  # or any relevant value to your environment
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: connector-api-tls-secret
        hosts:
          - api.connector.your-domain.com
ui:
  # --- Optional UI Ingress Configuration ---
  ingress:
    enabled: true
    host: "connector.your-domain.com"
    className: "nginx"  # or any relevant value to your environment
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: connector-ui-tls-secret
        hosts:
          - connector.your-domain.com
```
> [!WARNING]
> **Security Best Practices:**
> - Do not commit `my-values.yaml` with plain-textsecrets to version control
> - Use a Key Vault with the CSI Secret Store Driver for production
> - Consider a KMS with Managed Identity for database authentication   

</details>   

##### Install the chart using your custom values file:
```sh
helm install netapp-connector innovation-labsnetapp-connector --version 25.12.1 \
  --namespace netapp-connector \
  --create-namespace \
  -f my-values.yaml
```

> [!IMPORTANT]
> The connector requires the following mandatory values to start correctly:
> - `main.env.DATABASE_URL` - Connection string (auto-generated if `postgresql.enabled=true`)
> 
> **Database Options:**
> - Set `postgresql.enabled: true` to deploy PostgreSQL within the cluster (auto-configures `DATABASE_URL`)
> - Set `postgresql.enabled: false` and provide an external database URL explicitly

## Database Setup

The connector requires a database (PostgreSQL or MySQL) for storing connector data. You have two options:

<details>
<summary> Option 1: Built-in PostgreSQL (Recommended for Development/Testing)</summary>

Enable the integrated PostgreSQL deployment by setting `postgresql.enabled: true`. This will deploy a PostgreSQL StatefulSet with persistent storage.

**Advantages:**
- Simple setup with no external dependencies
- Automatic configuration (DATABASE_URL is auto-generated)
- Persistent storage with PersistentVolumeClaims
- InitContainer ensures database readiness before backend starts

**Configuration Example:**
```yaml
postgresql:
  enabled: true
  auth:
    username: postgres
    password: "secure-password"
    database: netappconnector
  persistence:
    enabled: true
    size: 10Gi
    storageClass: "myStorageClass"
```

**Auto-generated Connection String:**
```
postgresql://postgres:secure-password@neodb:5432/netappconnector
```
</details>

<details>
<summary> Option 2: External Database (Recommended for Production)</summary>

Use an external PostgreSQL or MySQL database by setting `postgresql.enabled: false` and providing the connection details.

**PostgreSQL Example:**
```yaml
postgresql:
  enabled: false

main:
  env:
    DB_TYPE: postgres
    DATABASE_URL: "postgresql://username:password@hostname:5432/database_name"
```

**MySQL Example:**
```yaml
postgresql:
  enabled: false

main:
  env:
    DB_TYPE: mysql
    DATABASE_URL: "mysql://username:password@hostname:3306/database_name"
```

**AWS RDS for PostgreSQL:**
```yaml
main:
  env:
    DB_TYPE: postgres
    DATABASE_URL: "postgresql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:5432/database_name?sslmode=require"
```

**AWS RDS for MySQL:**
```yaml
main:
  env:
    DB_TYPE: mysql
    DATABASE_URL: "mysql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:3306/database_name?ssl-mode=REQUIRED"
```

**Azure Database for PostgreSQL Flexible Server:**
```yaml
main:
  env:
    DB_TYPE: postgres
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.azure.com:5432/database_name?sslmode=require"
```

**Azure Database for MySQL Flexible Server:**
```yaml
main:
  env:
    DB_TYPE: mysql
    DATABASE_URL: "mysql://username:password@servername.mysql.database.azure.com:3306/database_name?ssl-mode=REQUIRED"
```

> [!TIP]
> **Security Best Practices:**
> - **Azure**: Use **Azure Managed Identity** instead of passwords for database authentication
> - **AWS**: Use **IAM Database Authentication** for password-less connections
> - Store connection strings in **Azure Key Vault** or **AWS Secrets Manager**
> - Enable **Microsoft Defender for Cloud** or **Amazon GuardDuty** for threat protection
> - Use **Azure Private Endpoint** or **AWS PrivateLink** to keep database traffic within your VNet/VPC
</details>


## Accessing the Application

After installation, you can access the application in several ways:

<details>
<summary> Option 1: Port Forwarding (Development)</summary>

Forward the UI service port to your local machine:

```sh
kubectl port-forward -n netapp-connector svc/netapp-connector-ui 8080:80
```

Then access the UI at `http://localhost:8080`
</details>

<details>
<summary> Option 2: Ingress (Production)</summary>

Enable Ingress in your `values.yaml` to expose the UI externally. The UI will automatically proxy API requests to the backend service.

### Generic Kubernetes with nginx Ingress Controller

For standard Kubernetes clusters using nginx Ingress Controller:

```yaml
main:
  service:
    type: ClusterIP
    port: 8080
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      # Session affinity for multi-replica deployments
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/session-cookie-name: "neo-session"
      nginx.ingress.kubernetes.io/session-cookie-max-age: "10800"  # 3 hours
      nginx.ingress.kubernetes.io/session-cookie-change-on-failure: "true"
    tls:
      - secretName: connector-api-tls-secret
        hosts:
          - api.connector.your-domain.com

ui:
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    host: "connector.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    tls:
      - secretName: connector-ui-tls-secret
        hosts:
          - connector.your-domain.com
```

Additionally, configure session affinity on the Service level:

```yaml
# Add to values.yaml
main:
  service:
    type: ClusterIP
    port: 8080
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
```

### Azure Kubernetes Service (AKS)

**Option A: Azure Application Gateway Ingress Controller (Recommended)**

For production AKS deployments, use Application Gateway with cookie-based affinity:

```yaml
main:
  service:
    type: ClusterIP
    port: 8080
    annotations:
      # Azure Load Balancer health probe
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/health"
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "azure-application-gateway"
    annotations:
      # SSL and routing
      appgw.ingress.kubernetes.io/ssl-redirect: "true"
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      
      # Cookie-based session affinity (survives pod scaling)
      appgw.ingress.kubernetes.io/cookie-based-affinity: "true"
      appgw.ingress.kubernetes.io/affinity-cookie-name: "neo-session"
      
      # Timeouts for long-running operations
      appgw.ingress.kubernetes.io/request-timeout: "1800"
      appgw.ingress.kubernetes.io/connection-draining-timeout: "30"
      
      # Health probe configuration
      appgw.ingress.kubernetes.io/health-probe-path: "/health"
      appgw.ingress.kubernetes.io/health-probe-interval: "30"
      appgw.ingress.kubernetes.io/health-probe-timeout: "30"
      appgw.ingress.kubernetes.io/health-probe-unhealthy-threshold: "3"
      
      # Backend pool settings
      appgw.ingress.kubernetes.io/backend-protocol: "http"
    tls:
      - secretName: connector-api-tls-cert
        hosts:
          - api.connector.your-domain.com

ui:
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    host: "connector.your-domain.com"
    className: "azure-application-gateway"
    annotations:
      appgw.ingress.kubernetes.io/ssl-redirect: "true"
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: connector-ui-tls-cert
        hosts:
          - connector.your-domain.com
```

**Option B: nginx Ingress Controller with Service-level Session Affinity**

If using nginx Ingress Controller on AKS:

```yaml
main:
  service:
    type: ClusterIP
    port: 8080
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/health"
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/session-cookie-name: "neo-session"
      nginx.ingress.kubernetes.io/session-cookie-max-age: "10800"
    tls:
      - secretName: connector-api-tls-cert
        hosts:
          - api.connector.your-domain.com
```

### Amazon Web Services (AWS) EKS

**Option A: AWS Application Load Balancer (ALB) - Recommended**

For production EKS deployments, use ALB Ingress Controller with sticky sessions:

```yaml
main:
  service:
    type: ClusterIP
    port: 8080
    annotations:
      # ALB target group attributes
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "30"
      service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: "deregistration_delay.timeout_seconds=30"
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "alb"
    annotations:
      # ALB Configuration
      alb.ingress.kubernetes.io/scheme: internal
      alb.ingress.kubernetes.io/target-type: ip
      
      # Sticky sessions with application cookie (survives pod scaling)
      alb.ingress.kubernetes.io/target-group-attributes: |
        stickiness.enabled=true,
        stickiness.type=app_cookie,
        stickiness.app_cookie.cookie_name=NEO-SESSION,
        stickiness.app_cookie.duration_seconds=10800,
        deregistration_delay.timeout_seconds=30
      
      # Health checks
      alb.ingress.kubernetes.io/healthcheck-path: /health
      alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
      alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '10'
      alb.ingress.kubernetes.io/healthy-threshold-count: '2'
      alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
      
      # Timeouts for long-running operations
      alb.ingress.kubernetes.io/load-balancer-attributes: |
        idle_timeout.timeout_seconds=1800
      
      # SSL/TLS
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: '443'
      alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id
      
      # Optional: WAF protection
      # alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:region:account:regional/webacl/name/id
    tls:
      - secretName: connector-api-tls-cert
        hosts:
          - api.connector.your-domain.com

ui:
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    host: "connector.your-domain.com"
    className: "alb"
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/healthcheck-path: /
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: '443'
      alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id
    tls:
      - secretName: connector-ui-tls-cert
        hosts:
          - connector.your-domain.com
```

**Option B: nginx Ingress Controller with Service-level Session Affinity**

If using nginx Ingress Controller on EKS:

```yaml
main:
  service:
    type: ClusterIP
    port: 8080
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/session-cookie-name: "neo-session"
      nginx.ingress.kubernetes.io/session-cookie-max-age: "10800"
    tls:
      - secretName: connector-api-tls-cert
        hosts:
          - api.connector.your-domain.com
```

### Google Cloud Platform (GCP) GKE

**Option A: GCP Load Balancer with BackendConfig (Recommended)**

For production GKE deployments, use BackendConfig for advanced session affinity:

First, create a BackendConfig resource (this will be added to your Helm templates):

```yaml
# This should be added to templates/neo-backendconfig.yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: {{ .Values.main.name }}-backend-config
  namespace: {{ .Release.Namespace }}
spec:
  # Session affinity configuration
  sessionAffinity:
    affinityType: "CLIENT_IP_PORT_PROTO"
    affinityCookieTtlSec: 10800  # 3 hours
  
  # Connection draining for graceful pod termination
  connectionDraining:
    drainingTimeoutSec: 30
  
  # Timeout for long-running operations
  timeoutSec: 1800  # 30 minutes
  
  # Health check configuration
  healthCheck:
    checkIntervalSec: 30
    timeoutSec: 10
    healthyThreshold: 2
    unhealthyThreshold: 2
    type: HTTP
    requestPath: /health
    port: {{ .Values.main.env.PORT }}
```

Then configure your values.yaml:

```yaml
main:
  service:
    type: ClusterIP
    port: 8080
    annotations:
      cloud.google.com/neg: '{"ingress": true}'
      cloud.google.com/backend-config: '{"default": "netapp-connector-main-backend-config"}'
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "gce"
    annotations:
      # GCP-specific annotations
      kubernetes.io/ingress.class: "gce"
      kubernetes.io/ingress.global-static-ip-name: "neo-api-static-ip"
      
      # Managed SSL certificates
      networking.gke.io/managed-certificates: "neo-api-managed-cert"
      
      # Backend configuration with session affinity
      cloud.google.com/backend-config: '{"default": "netapp-connector-main-backend-config"}'
      
      # Optional: Cloud Armor for WAF protection
      # cloud.google.com/armor-config: '{"default": "neo-security-policy"}'
      
      # Network Endpoint Groups for better performance
      cloud.google.com/neg: '{"ingress": true}'
    tls:
      - secretName: connector-api-tls-cert
        hosts:
          - api.connector.your-domain.com

ui:
  service:
    type: ClusterIP
    port: 80
    annotations:
      cloud.google.com/neg: '{"ingress": true}'
  ingress:
    enabled: true
    host: "connector.your-domain.com"
    className: "gce"
    annotations:
      kubernetes.io/ingress.class: "gce"
      kubernetes.io/ingress.global-static-ip-name: "neo-ui-static-ip"
      networking.gke.io/managed-certificates: "neo-ui-managed-cert"
      cloud.google.com/neg: '{"ingress": true}'
    tls:
      - secretName: connector-ui-tls-cert
        hosts:
          - connector.your-domain.com
```

Create a ManagedCertificate resource (add to templates/neo-managed-cert.yaml):

```yaml
{{- if and .Values.main.ingress.enabled (eq .Values.main.ingress.className "gce") }}
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: neo-api-managed-cert
  namespace: {{ .Release.Namespace }}
spec:
  domains:
    - {{ .Values.main.ingress.host }}
{{- end }}
```

**Option B: nginx Ingress Controller with Service-level Session Affinity**

If using nginx Ingress Controller on GKE:

```yaml
main:
  service:
    type: ClusterIP
    port: 8080
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
    annotations:
      cloud.google.com/neg: '{"ingress": true}'
  ingress:
    enabled: true
    host: "api.connector.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/session-cookie-name: "neo-session"
      nginx.ingress.kubernetes.io/session-cookie-max-age: "10800"
    tls:
      - secretName: connector-api-tls-cert
        hosts:
          - api.connector.your-domain.com
```

### Session Affinity Comparison

| Platform | Recommended Approach | Timeout | Survives Pod Scaling | Best For |
|----------|---------------------|---------|---------------------|----------|
| **Azure AKS** | Application Gateway cookie affinity | 3 hours | ✅ Yes | Production deployments with WAF |
| **AWS EKS** | ALB sticky sessions (app_cookie) | 3 hours | ✅ Yes | Production deployments with AWS integration |
| **GCP GKE** | BackendConfig CLIENT_IP_PORT_PROTO | 3 hours | ✅ Yes | Production deployments with GCP services |
| **Generic K8s** | nginx cookie affinity + Service ClientIP | 3 hours | ⚠️ Partial | Development and multi-cloud |

### Important Notes

> [!IMPORTANT]
> **Session Affinity Requirements:**
> - **Minimum timeout**: 1800 seconds (30 minutes) for file operations
> - **Recommended timeout**: 10800 seconds (3 hours) for long-running Microsoft Graph operations
> - **Never use**: 60 seconds or less - this will break active sessions
> 
> When scaling backend replicas (`.Values.main.replicaCount > 1`):
> - Use cloud-native load balancers with cookie-based affinity when possible
> - Cookie-based affinity survives pod restarts and scaling operations
> - ClientIP affinity is simpler but breaks during pod scaling
> - Always enable connection draining to handle graceful shutdowns

</details>

<details>
<summary> Option 3: Load Balancer (Public IP)</summary>

For direct access without Ingress:

**Azure Load Balancer:**
```yaml
ui:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-resource-group: "myResourceGroup"
```

**AWS Network Load Balancer:**
```yaml
ui:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```
</details>

## Component Communication

The chart implements a three-tier architecture with automatic service discovery:

### UI to Backend Communication
- UI nginx proxies `/api/*` requests to `http://netapp-connector-main:8080`
- Configured via `NEO_API` environment variable in the UI deployment
- No manual configuration required

### Backend to Database Communication
- **Built-in PostgreSQL**: `DATABASE_URL` is auto-generated as `postgresql://postgres:password@neodb:5432/database`
- **External Database**: Manually specify `DATABASE_URL` in values.yaml
- InitContainer ensures PostgreSQL is ready before backend starts

## Upgrading the Chart

To upgrade an existing release, use `helm upgrade`. The `--reuse-values` flag is recommended to preserve your existing configuration, including secrets.

```sh
# 1. Update your local chart repository
helm repo update

# 2. Upgrade the release to a new version
helm upgrade netapp-connector innovation-labs/netapp-connector \
  --namespace netapp-connector \
  --reuse-values \
  --set main.image.tag="3.1.0" \
  --set ui.image.tag="3.1.0"
```

**Upgrading with a values file:**
```sh
helm upgrade netapp-connector innovation-labs/netapp-connector \
  --namespace netapp-connector \
  -f my-values.yaml
```

## Uninstallation

To uninstall and delete the `netapp-connector` release:

```sh
helm uninstall netapp-connector --namespace netapp-connector
```

> [!WARNING]
> **Data Persistence Note:**
> If you enabled the built-in PostgreSQL (`postgresql.enabled: true`), the PersistentVolumeClaim (PVC) will remain after uninstallation to prevent accidental data loss. 
> 
> To completely remove all data:
> ```sh
> # List PVCs
> kubectl get pvc -n netapp-connector
> 
> # Delete PostgreSQL PVC (this will delete all database data)
> kubectl delete pvc data-neodb-0 -n netapp-connector
> ```

> [!NOTE]
> If using an external database, your data will remain intact as it's managed separately from the Helm chart.

## Configuration Parameters

### Backend (Main) Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `main.name` | The base name for backend resources. | `netapp-connector-main` |
| `main.replicaCount` | Number of backend connector pods to run. | `1` |
| `main.image.repository` | The backend container image repository. | `ghcr.io/netapp/netapp-copilot-connector` |
| `main.image.tag` | The backend container image tag. If empty, defaults to chart's `appVersion`. | `""` |
| `main.image.pullPolicy` | The image pull policy. | `Always` |
| `main.service.type` | The type of Kubernetes service to create for backend. | `ClusterIP` |
| `main.service.port` | The port exposed by the backend service and container. | `8080` |
| `main.ingress.enabled` | If true, create an Ingress resource for the backend API. | `false` |
| `main.ingress.host` | The hostname for the backend Ingress rule. | `nil` |
| `main.ingress.path` | The path for the backend Ingress rule. | `/` |
| `main.ingress.pathType` | The path type for the Ingress rule. | `Prefix` |
| `main.ingress.className` | The `ingressClassName` to associate with the Ingress. | `""` |
| `main.ingress.annotations` | Annotations for the Ingress resource. | `{}` |
| `main.ingress.tls` | Ingress TLS configuration. | `[]` |
| `main.env.PORT` | The port the backend application runs on. | `8080` |
| `main.env.PYTHONUNBUFFERED` | Python unbuffered output. | `1` |
| `main.env.DATABASE_URL` | Database connection URL. Auto-generated if `postgresql.enabled=true`. | `""` |

### UI Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ui.name` | The base name for UI resources. | `netapp-connector-ui` |
| `ui.replicaCount` | Number of UI pods to run. | `1` |
| `ui.image.repository` | The UI container image repository. | `ghcr.io/beezy-dev/neo-ui-framework` |
| `ui.image.tag` | UI image tag. | `3.1.0` |
| `ui.image.pullPolicy` | The image pull policy. | `Always` |
| `ui.service.type` | The type of Kubernetes service to create for UI. | `ClusterIP` |
| `ui.service.port` | The port exposed by the UI service. | `80` |
| `ui.ingress.enabled` | If true, create an Ingress resource for the UI. | `false` |
| `ui.ingress.host` | The hostname for the UI Ingress rule. | `nil` |
| `ui.ingress.path` | The path for the UI Ingress rule. | `/` |
| `ui.ingress.pathType` | The path type for the Ingress rule. | `Prefix` |
| `ui.ingress.className` | The `ingressClassName` to associate with the Ingress. | `""` |
| `ui.ingress.annotations` | Annotations for the Ingress resource. | `{}` |
| `ui.ingress.tls` | Ingress TLS configuration. | `[]` |
| `ui.env.PORT` | The port the UI nginx server runs on. | `80` |

### PostgreSQL Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable or disable PostgreSQL deployment. | `false` |
| `postgresql.name` | The name for PostgreSQL resources. | `neodb` |
| `postgresql.image.repository` | PostgreSQL container image repository. | `docker.io/library/postgres` |
| `postgresql.image.tag` | PostgreSQL image tag. | `16.10-alpine3.21` |
| `postgresql.image.pullPolicy` | PostgreSQL image pull policy. | `IfNotPresent` |
| `postgresql.auth.username` | PostgreSQL username. | `postgres` |
| `postgresql.auth.password` | PostgreSQL password. **Should be changed for production.** | `neodbsecret` |
| `postgresql.auth.database` | PostgreSQL database name. | `netappconnector` |
| `postgresql.service.type` | PostgreSQL service type. | `ClusterIP` |
| `postgresql.service.port` | PostgreSQL service port. | `5432` |
| `postgresql.persistence.enabled` | Enable persistent storage for PostgreSQL. | `true` |
| `postgresql.persistence.storageClass` | StorageClass for PostgreSQL PVC. Empty uses default. | `""` |
| `postgresql.persistence.accessMode` | PVC access mode. | `ReadWriteOnce` |
| `postgresql.persistence.annotations` | PVC annotations. | `{}` |
| `postgresql.resources` | Resource requests and limits for PostgreSQL pod. | `{}` |

## Networking Architecture

The chart creates the following networking topology:

```
┌─────────────────────────────────────────────────────┐
│              External Access Layer                  │
│              (Ingress Controller)                   │
└────────────────────┬────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
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
│ /api/* → :8080  │     │   InitContainer  │
│                 │     │   waits for DB   │
└─────────────────┘     └──────────┬───────┘
                                   │
                                   ▼
                        ┌──────────────────────────┐
                        │       Database           │
                        ├──────────────────────────┤
                        │ Option 1: Built-in       │
                        │ - PostgreSQL StatefulSet │
                        │ - PVC (8Gi default)      │
                        │ - Auto-configured URL    │
                        ├──────────────────────────┤
                        │ Option 2: External       │
                        │ - Azure DB for PostgreSQL│
                        │ - AWS RDS for PostgreSQL │
                        │ - Amazon Aurora          │
                        │ - Manual URL config      │
                        └──────────────────────────┘
```

### Key Networking Features:

1. **Nginx Reverse Proxy**: UI automatically proxies `/api/*` to backend
2. **InitContainer**: Waits for database readiness before starting backend
3. **Auto-generated URLs**: Built-in PostgreSQL connection string created automatically
4. **Service Discovery**: Kubernetes DNS for internal service-to-service communication

## Troubleshooting

### Check Pod Status

```sh
kubectl get pods -n netapp-connector
```

Expected output:
```
NAME                                     READY   STATUS    RESTARTS   AGE
netapp-connector-main-xxxx               1/1     Running   0          5m
netapp-connector-ui-xxxx                 1/1     Running   0          5m
neodb-0                                  1/1     Running   0          5m
```

### View Backend Logs

```sh
# View main container logs
kubectl logs -n netapp-connector -l component=netapp-connector-main -f

# View initContainer logs (database wait)
kubectl logs -n netapp-connector -l component=netapp-connector-main -c wait-for-db
```

### View UI Logs

```sh
kubectl logs -n netapp-connector -l component=netapp-connector-ui -f
```

### View PostgreSQL Logs (if enabled)

```sh
kubectl logs -n netapp-connector -l component=neodb -f
```

### Test Backend Connectivity from UI Pod

```sh
kubectl exec -n netapp-connector -it deployment/netapp-connector-ui -- curl http://netapp-connector-main:8080/health
```

### Verify Database Connection

```sh
# Check DATABASE_URL (sensitive - be careful in production)
kubectl exec -n netapp-connector -it deployment/netapp-connector-main -- env | grep DATABASE_URL

# Test PostgreSQL connection (built-in)
kubectl exec -n netapp-connector -it statefulset/neodb -- pg_isready -U postgres
```

### Test PostgreSQL Connection (if built-in PostgreSQL is enabled)

```sh
# Get PostgreSQL password
PGPASSWORD=$(kubectl get secret neodb-secret -n netapp-connector -o jsonpath='{.data.password}' | base64 -d)

# Connect to PostgreSQL
kubectl exec -it -n netapp-connector statefulset/neodb -- psql -U postgres -d netappconnector

# Run a test query
\dt  # List tables
\q   # Quit
```

### Check PostgreSQL PVC Status

```sh
kubectl get pvc -n netapp-connector
kubectl describe pvc data-neodb-0 -n netapp-connector
```

### Verify ConfigMaps and Secrets

```sh
# Check ConfigMap
kubectl get configmap netapp-connector-main -n netapp-connector -o yaml

# Check Secret (base64 encoded)
kubectl get secret netapp-connector-main -n netapp-connector -o yaml

# Decode a specific secret value
kubectl get secret netapp-connector-main -n netapp-connector -o jsonpath='{.data.MS_GRAPH_CLIENT_ID}' | base64 -d
```

### Common Issues

#### 1. PostgreSQL Pod Not Starting

**Symptom**: `neodb-0` pod stuck in `Pending` or `Init` state

**Solutions**:

```sh
# Check PVC status
kubectl get pvc -n netapp-connector
kubectl describe pvc data-neodb-0 -n netapp-connector

# Check StorageClass
kubectl get storageclass

# For AKS, ensure you have a valid StorageClass
# Default AKS StorageClasses: default, managed, managed-premium
```

**Fix for missing StorageClass**:
```yaml
postgresql:
  persistence:
    # For Azure AKS
    storageClass: "managed-premium"  # or "default"
    
    # For AWS EKS
    storageClass: "gp3"  # or "gp2" for General Purpose SSD
```

#### 2. Backend Cannot Connect to Database

**Symptom**: Backend pod shows database connection errors in logs

**Solutions**:

```sh
# 1. Verify PostgreSQL service exists
kubectl get svc neodb -n netapp-connector

# 2. Check DATABASE_URL format
kubectl get secret netapp-connector-main -n netapp-connector -o jsonpath='{.data.DATABASE_URL}' | base64 -d

# 3. Test database connectivity from backend pod
kubectl exec -n netapp-connector -it deployment/netapp-connector-main -- nc -zv neodb 5432

# 4. Check PostgreSQL readiness
kubectl exec -n netapp-connector -it statefulset/neodb -- pg_isready -U postgres
```

#### 3. InitContainer Stuck Waiting for Database

**Symptom**: Backend pod shows `Init:0/1` status

**Solutions**:

```sh
# Check initContainer logs
kubectl logs -n netapp-connector -l component=netapp-connector-main -c wait-for-db

# Check PostgreSQL pod status
kubectl describe pod -n netapp-connector neodb-0

# Verify PostgreSQL credentials match
kubectl get secret neodb-secret -n netapp-connector -o jsonpath='{.data.password}' | base64 -d
kubectl get secret netapp-connector-main -n netapp-connector -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

#### 4. UI Cannot Reach Backend API

**Symptom**: UI loads but API calls fail with 502/503 errors

**Solutions**:

```sh
# 1. Verify backend service
kubectl get svc netapp-connector-main -n netapp-connector

# 2. Test from UI pod
kubectl exec -n netapp-connector -it deployment/netapp-connector-ui -- curl -v http://netapp-connector-main:8080/health

# 3. Check nginx proxy configuration
kubectl exec -n netapp-connector -it deployment/netapp-connector-ui -- cat /etc/nginx/conf.d/default.conf

# 4. Check NEO_API environment variable
kubectl exec -n netapp-connector -it deployment/netapp-connector-ui -- env | grep NEO_API
```

#### 5. Missing DB_TYPE Error

**Symptom**: Error: `couldn't find key DB_TYPE in Secret`

**Solution**: Ensure ConfigMap has `DB_TYPE` defined:

```sh
# Verify ConfigMap contains DB_TYPE
kubectl get configmap netapp-connector-main -n netapp-connector -o jsonpath='{.data.DB_TYPE}'

# If missing, upgrade with correct value
helm upgrade netapp-connector . --reuse-values --set main.env.DB_TYPE=postgres
```

#### 6. Cloud-Specific Issues

**Azure Application Gateway Ingress Controller (AGIC) not working**:

```sh
# Check AGIC pod status
kubectl get pods -n kube-system | grep ingress-azure

# Verify Ingress annotations
kubectl describe ingress -n netapp-connector

# Check Application Gateway backend health
az network application-gateway show-backend-health \
  --name myAppGateway \
  --resource-group myResourceGroup
```

**AWS Load Balancer Controller issues**:

```sh
# Check AWS Load Balancer Controller pod status
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Verify Ingress or Service annotations
kubectl describe ingress -n netapp-connector
kubectl describe svc netapp-connector-ui -n netapp-connector

# Check AWS Load Balancer status
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `netapp-connector`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}'
```

**Azure Database for PostgreSQL connection issues**:

```sh
# Ensure SSL is required in connection string
DATABASE_URL: "postgresql://user@server:pass@server.postgres.database.azure.com:5432/db?sslmode=require"

# Check firewall rules allow AKS egress
az postgres flexible-server firewall-rule list \
  --resource-group myResourceGroup \
  --name myPostgresServer

# For Private Endpoint, verify VNet peering
az network vnet peering list \
  --resource-group myResourceGroup \
  --vnet-name myAKSVNet
```

**AWS RDS for PostgreSQL connection issues**:

```sh
# Ensure SSL is enabled in connection string
DATABASE_URL: "postgresql://user:pass@instance.xxxxx.us-east-1.rds.amazonaws.com:5432/db?sslmode=require"

# Check security group allows EKS node security group
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --region us-east-1

# Verify RDS instance is accessible
aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --region us-east-1 \
  --query 'DBInstances[0].{Endpoint:Endpoint.Address,Port:Endpoint.Port,Status:DBInstanceStatus}'

# For private subnets, verify VPC peering or Transit Gateway
aws ec2 describe-vpc-peering-connections \
  --region us-east-1 \
  --filters "Name=status-code,Values=active"
```

### Debug Mode

Enable verbose logging for troubleshooting:

```yaml
main:
  env:
    PYTHONUNBUFFERED: "1"  # Enable immediate log output
```

View real-time logs:
```sh
# Backend
kubectl logs -n netapp-connector -l component=netapp-connector-main -f --tail=100

# UI
kubectl logs -n netapp-connector -l component=netapp-connector-ui -f --tail=100

# PostgreSQL
kubectl logs -n netapp-connector -l component=neodb -f --tail=100
```

## Cloud-Specific Best Practices

### Azure Best Practices

#### 1. Use Azure Key Vault for Secrets

Instead of storing secrets in Helm values:

```yaml
# Install Azure Key Vault Provider for Secrets Store CSI Driver
helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --generate-name
```

#### 2. Use Managed Identity

Configure workload identity for database access:

```sh
# Enable workload identity on AKS
az aks update \
  --resource-group myResourceGroup \
  --name myAKSCluster \
  --enable-workload-identity \
  --enable-oidc-issuer
```

#### 3. Enable Azure Monitor

```sh
# Enable Container Insights
az aks enable-addons \
  --resource-group myResourceGroup \
  --name myAKSCluster \
  --addons monitoring
```

#### 4. Use Azure Database for PostgreSQL

For production, use managed database:

```sh
# Create Azure Database for PostgreSQL Flexible Server
az postgres flexible-server create \
  --resource-group myResourceGroup \
  --name myPostgresServer \
  --location eastus \
  --admin-user myadmin \
  --admin-password <password> \
  --sku-name Standard_D2s_v3 \
  --version 16 \
  --storage-size 128 \
  --high-availability Enabled \
  --zone 1 \
  --standby-zone 2
```

### AWS Best Practices

#### 1. Use AWS Secrets Manager for Secrets

Instead of storing secrets in Helm values:

```sh
# Install AWS Secrets and Configuration Provider (ASCP)
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system

# Install AWS Provider
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

#### 2. Use IAM Roles for Service Accounts (IRSA)

Configure IAM authentication for database access:

```sh
# Create IAM policy for RDS access
aws iam create-policy \
  --policy-name NetAppConnectorRDSPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["rds-db:connect"],
      "Resource": ["arn:aws:rds-db:us-east-1:123456789012:dbuser:*/dbuser"]
    }]
  }'

# Associate IAM role with Kubernetes service account
eksctl create iamserviceaccount \
  --name netapp-connector-sa \
  --namespace netapp-connector \
  --cluster myEKSCluster \
  --attach-policy-arn arn:aws:iam::123456789012:policy/NetAppConnectorRDSPolicy \
  --approve
```

#### 3. Enable Amazon CloudWatch Container Insights

```sh
# Enable Container Insights for EKS
aws eks update-cluster-config \
  --region us-east-1 \
  --name myEKSCluster \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'

# Install CloudWatch agent
eksctl utils install-cloudwatch-observability \
  --cluster myEKSCluster \
  --region us-east-1
```

#### 4. Use Amazon RDS for PostgreSQL

For production, use managed database:

```sh
# Create RDS PostgreSQL instance with Multi-AZ
aws rds create-db-instance \
  --db-instance-identifier netapp-connector-db \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 16.1 \
  --master-username postgres \
  --master-user-password <secure-password> \
  --allocated-storage 100 \
  --storage-type gp3 \
  --storage-encrypted \
  --multi-az \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name mySubnetGroup \
  --publicly-accessible false \
  --enable-iam-database-authentication \
  --region us-east-1

# Enable automated backups to S3
aws rds modify-db-instance \
  --db-instance-identifier netapp-connector-db \
  --backup-retention-period 30 \
  --apply-immediately
```

**Using Amazon Aurora PostgreSQL (recommended for high availability):**

```sh
# Create Aurora PostgreSQL cluster
aws rds create-db-cluster \
  --db-cluster-identifier netapp-connector-cluster \
  --engine aurora-postgresql \
  --engine-version 16.1 \
  --master-username postgres \
  --master-user-password <secure-password> \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name mySubnetGroup \
  --storage-encrypted \
  --enable-iam-database-authentication \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --region us-east-1

# Create cluster instances (primary and replica)
aws rds create-db-instance \
  --db-instance-identifier netapp-connector-instance-1 \
  --db-cluster-identifier netapp-connector-cluster \
  --db-instance-class db.r6g.large \
  --engine aurora-postgresql \
  --region us-east-1
```
