# Deploy using Helm Charts

This Helm chart deploys NetApp Project Neo v4 on a Kubernetes cluster using `Deployment` resources for scalable application management.

## Overview

The chart bootstraps a deployment of NetApp Project Neo, which includes the following Kubernetes resources:
- **Deployments**: Manages the API, Worker, Extractor, NER, and UI pods with configurable replicas and rolling updates.
- **Services**: Exposes each microservice within the cluster on stable endpoints, with optional external access for the API and UI.
- **Secrets**: Securely stores sensitive credentials like Microsoft Graph API keys, encryption keys, JWT secrets, and database connection details.
- **ConfigMaps**: Provide non-sensitive environment variables for each service. The UI bundles its nginx config, so no ConfigMap mount is required.
- **StatefulSet**: (Optional) Manages PostgreSQL 17 database with persistent storage when enabled.
- **Ingress**: (Optional) Manages external access to the API and UI services.

## Architecture

The chart deploys up to six main components:

1. **API Service** (`neo-api`): The user-facing FastAPI service on port 8000. Handles REST API requests, MCP transport, OAuth authentication, and coordinates with backend services.
2. **Worker Service** (`neo-worker`): Background processing service that manages crawling, Microsoft Graph uploads, NER orchestration, and connection lifecycle. Requires `SYS_ADMIN` and `DAC_READ_SEARCH` capabilities.
3. **Extractor Service** (`neo-extractor`): Content extraction service that processes documents from connected data sources. Requires privileged mode for NFS/CIFS mount operations.
4. **NER Service** (`neo-ner`): Named Entity Recognition service powered by GLiNER2. Optional GPU support via NVIDIA CUDA or AMD ROCm for accelerated inference.
5. **UI** (`neo-ui`): A web console on port 8081 that communicates with the API service through an nginx reverse proxy.
6. **PostgreSQL Database** (`neo-postgres`): (Optional) An integrated PostgreSQL 17 database for application data storage.

### Key Features

- **Microservice Architecture**: Each service scales independently with dedicated resource allocation
- **Auto-configured Database URL**: When using the built-in PostgreSQL, the `DATABASE_URL` is automatically generated from PostgreSQL settings and shared across all services
- **InitContainer Health Check**: Ensures PostgreSQL is ready before starting services
- **Nginx Reverse Proxy**: UI automatically proxies API requests from `/api/*` to the API service
- **Separation of Concerns**: Non-sensitive configuration in ConfigMaps, sensitive data in Secrets
- **Self-contained UI nginx config**: UI image embeds the nginx template; ConfigMap/volume mounts are not needed
- **Inter-service Communication**: Services discover each other through Kubernetes DNS using service URLs
- **GPU Support**: Optional NVIDIA CUDA or AMD ROCm acceleration for the NER service
- **Post-install Configuration**: Microsoft Graph credentials and licenses are configured through the product UI/API after deployment

## Prerequisites

- Kubernetes cluster (v1.24+ recommended)
- Helm package manager (v3.8+)
- Database for application data storage:
  - **Option 1**: Enable the built-in PostgreSQL deployment (`postgresql.enabled: true`)
  - **Option 2**: Use an external database (PostgreSQL or MySQL)
- (Optional) StorageClass for persistent volumes if using the built-in PostgreSQL
- (Optional) NVIDIA GPU nodes with `nvidia-container-toolkit` installed for GPU-accelerated NER inference
- Microsoft Graph API credentials (configured post-installation)

> [!NOTE]
> **Elevated Privileges**: The Worker service requires `SYS_ADMIN` and `DAC_READ_SEARCH` Linux capabilities. The Extractor service requires privileged mode for NFS/CIFS mount operations. Ensure your cluster security policies allow these capabilities.

## Installation Guide

### 1. Add Helm Repository

First, add the NetApp Innovation Labs repository to your Helm client.

```sh
helm repo add innovation-labs https://netapp.github.io/Innovation-Labs/
helm repo update
```

### 2. Install the Chart

There are two primary methods for installing the chart: using command-line flags (ideal for testing) or a custom values file (recommended for production).

#### Method 1: Using Command-Line Flags (for Development)

<details>
  <summary> Option A: With Built-in PostgreSQL (Auto-configured)</summary>

```sh
helm install netapp-neo innovation-labs/netapp-neo \
  --namespace netapp-neo \
  --create-namespace \
  --set postgresql.enabled=true \
  --set postgresql.auth.password="your-secure-password" \
  --set postgresql.auth.database="neo_connector"
```

</details>

<details>
<summary> Option B: With External Database </summary>

```sh
helm install netapp-neo innovation-labs/netapp-neo \
  --namespace netapp-neo \
  --create-namespace \
  --set postgresql.enabled=false \
  --set api.env.DB_TYPE="postgres" \
  --set api.env.DATABASE_URL="postgresql://user:password@external-host:5432/neo_connector"
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
    database: neo_connector
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

api:
  # --- Internal Database Configuration ---
  env:
    DATABASE_URL: ""  # Auto-generated when postgresql.enabled=true
  # --- Optional API Ingress Configuration ---
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
    className: "nginx"  # or any relevant value to your environment
    tls:
      - secretName: neo-api-tls-secret
        hosts:
          - api.neo.your-domain.com

worker:
  env: {}  # DATABASE_URL auto-configured

extractor:
  env: {}  # DATABASE_URL auto-configured

ner:
  env: {}  # DATABASE_URL auto-configured

ui:
  # --- Optional UI Ingress Configuration ---
  ingress:
    enabled: true
    host: "neo.your-domain.com"
    className: "nginx"
    tls:
      - secretName: neo-ui-tls-secret
        hosts:
          - neo.your-domain.com
```
</details>

<details>
<summary>Option B: With External Database</summary>

```yaml
# my-values.yaml
# Disable built-in PostgreSQL
postgresql:
  enabled: false

api:
  # --- External Database Configuration ---
  env:
    # For PostgreSQL
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.mydomain.com:5432/neo_connector" # parameter like ?sslmode=require could be added
    # For MySQL
    # DATABASE_URL: "mysql://username:password@hostname:3306/neo_connector"
  # --- Optional API Ingress Configuration ---
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
    className: "nginx"  # or any relevant value to your environment
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: neo-api-tls-secret
        hosts:
          - api.neo.your-domain.com

worker:
  env:
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.mydomain.com:5432/neo_connector"

extractor:
  env:
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.mydomain.com:5432/neo_connector"

ner:
  env:
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.mydomain.com:5432/neo_connector"

ui:
  # --- Optional UI Ingress Configuration ---
  ingress:
    enabled: true
    host: "neo.your-domain.com"
    className: "nginx"  # or any relevant value to your environment
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: neo-ui-tls-secret
        hosts:
          - neo.your-domain.com
```
> [!WARNING]
> **Security Best Practices:**
> - Do not commit `my-values.yaml` with plain-text secrets to version control
> - Use a Key Vault with the CSI Secret Store Driver for production
> - Consider a KMS with Managed Identity for database authentication

</details>

##### Install the chart using your custom values file:
```sh
helm install netapp-neo innovation-labs/netapp-neo \
  --namespace netapp-neo \
  --create-namespace \
  -f my-values.yaml
```

> [!IMPORTANT]
> All services require the following mandatory values to start correctly:
> - `DATABASE_URL` - Connection string (auto-generated for all services if `postgresql.enabled=true`)
>
> **Database Options:**
> - Set `postgresql.enabled: true` to deploy PostgreSQL within the cluster (auto-configures `DATABASE_URL` for all services)
> - Set `postgresql.enabled: false` and provide an external database URL in each service's env section

## Database Setup

Project Neo requires a database (PostgreSQL or MySQL) for storing application data. You have two options:

<details>
<summary> Option 1: Built-in PostgreSQL (Recommended for Development/Testing)</summary>

Enable the integrated PostgreSQL 17 deployment by setting `postgresql.enabled: true`. This will deploy a PostgreSQL StatefulSet with persistent storage.

**Advantages:**
- Simple setup with no external dependencies
- Automatic configuration (DATABASE_URL is auto-generated for all services)
- Persistent storage with PersistentVolumeClaims
- InitContainer ensures database readiness before services start

**Configuration Example:**
```yaml
postgresql:
  enabled: true
  auth:
    username: postgres
    password: "secure-password"
    database: neo_connector
  persistence:
    enabled: true
    size: 10Gi
    storageClass: "myStorageClass"
```

**Auto-generated Connection String:**
```
postgresql://postgres:secure-password@neo-postgres:5432/neo_connector
```
</details>

<details>
<summary> Option 2: External Database (Recommended for Production)</summary>

Use an external PostgreSQL or MySQL database by setting `postgresql.enabled: false` and providing the connection details for each service.

**PostgreSQL Example:**
```yaml
postgresql:
  enabled: false

api:
  env:
    DB_TYPE: postgres
    DATABASE_URL: "postgresql://username:password@hostname:5432/neo_connector"

worker:
  env:
    DATABASE_URL: "postgresql://username:password@hostname:5432/neo_connector"

extractor:
  env:
    DATABASE_URL: "postgresql://username:password@hostname:5432/neo_connector"

ner:
  env:
    DATABASE_URL: "postgresql://username:password@hostname:5432/neo_connector"
```

**MySQL Example:**
```yaml
postgresql:
  enabled: false

api:
  env:
    DB_TYPE: mysql
    DATABASE_URL: "mysql://username:password@hostname:3306/neo_connector"

worker:
  env:
    DATABASE_URL: "mysql://username:password@hostname:3306/neo_connector"

extractor:
  env:
    DATABASE_URL: "mysql://username:password@hostname:3306/neo_connector"

ner:
  env:
    DATABASE_URL: "mysql://username:password@hostname:3306/neo_connector"
```

**AWS RDS for PostgreSQL:**
```yaml
api:
  env:
    DB_TYPE: postgres
    DATABASE_URL: "postgresql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:5432/neo_connector?sslmode=require"

worker:
  env:
    DATABASE_URL: "postgresql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:5432/neo_connector?sslmode=require"

extractor:
  env:
    DATABASE_URL: "postgresql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:5432/neo_connector?sslmode=require"

ner:
  env:
    DATABASE_URL: "postgresql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:5432/neo_connector?sslmode=require"
```

**AWS RDS for MySQL:**
```yaml
api:
  env:
    DB_TYPE: mysql
    DATABASE_URL: "mysql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:3306/neo_connector?ssl-mode=REQUIRED"

worker:
  env:
    DATABASE_URL: "mysql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:3306/neo_connector?ssl-mode=REQUIRED"

extractor:
  env:
    DATABASE_URL: "mysql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:3306/neo_connector?ssl-mode=REQUIRED"

ner:
  env:
    DATABASE_URL: "mysql://username:password@database-instance.xxxxx.us-east-1.rds.amazonaws.com:3306/neo_connector?ssl-mode=REQUIRED"
```

**Azure Database for PostgreSQL Flexible Server:**
```yaml
api:
  env:
    DB_TYPE: postgres
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.azure.com:5432/neo_connector?sslmode=require"

worker:
  env:
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.azure.com:5432/neo_connector?sslmode=require"

extractor:
  env:
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.azure.com:5432/neo_connector?sslmode=require"

ner:
  env:
    DATABASE_URL: "postgresql://username@servername:password@servername.postgres.database.azure.com:5432/neo_connector?sslmode=require"
```

**Azure Database for MySQL Flexible Server:**
```yaml
api:
  env:
    DB_TYPE: mysql
    DATABASE_URL: "mysql://username:password@servername.mysql.database.azure.com:3306/neo_connector?ssl-mode=REQUIRED"

worker:
  env:
    DATABASE_URL: "mysql://username:password@servername.mysql.database.azure.com:3306/neo_connector?ssl-mode=REQUIRED"

extractor:
  env:
    DATABASE_URL: "mysql://username:password@servername.mysql.database.azure.com:3306/neo_connector?ssl-mode=REQUIRED"

ner:
  env:
    DATABASE_URL: "mysql://username:password@servername.mysql.database.azure.com:3306/neo_connector?ssl-mode=REQUIRED"
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
kubectl port-forward -n netapp-neo svc/neo-ui 8081:80
```

Then access the UI at `http://localhost:8081`

To access the API directly:

```sh
kubectl port-forward -n netapp-neo svc/neo-api 8000:8000
```

Then access the API at `http://localhost:8000`
</details>

<details>
<summary> Option 2: Ingress (Production)</summary>

Enable Ingress in your `values.yaml` to expose the UI and API externally. The UI will automatically proxy API requests to the API service.

### Generic Kubernetes with nginx Ingress Controller

For standard Kubernetes clusters using nginx Ingress Controller:

```yaml
api:
  service:
    type: ClusterIP
    port: 8000
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
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
      - secretName: neo-api-tls-secret
        hosts:
          - api.neo.your-domain.com

ui:
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    host: "neo.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    tls:
      - secretName: neo-ui-tls-secret
        hosts:
          - neo.your-domain.com
```

Additionally, configure session affinity on the Service level:

```yaml
# Add to values.yaml
api:
  service:
    type: ClusterIP
    port: 8000
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
```

### Azure Kubernetes Service (AKS)

**Option A: Azure Application Gateway Ingress Controller (Recommended)**

For production AKS deployments, use Application Gateway with cookie-based affinity:

```yaml
api:
  service:
    type: ClusterIP
    port: 8000
    annotations:
      # Azure Load Balancer health probe
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/health"
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
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
      - secretName: neo-api-tls-cert
        hosts:
          - api.neo.your-domain.com

ui:
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    host: "neo.your-domain.com"
    className: "azure-application-gateway"
    annotations:
      appgw.ingress.kubernetes.io/ssl-redirect: "true"
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: neo-ui-tls-cert
        hosts:
          - neo.your-domain.com
```

**Option B: nginx Ingress Controller with Service-level Session Affinity**

If using nginx Ingress Controller on AKS:

```yaml
api:
  service:
    type: ClusterIP
    port: 8000
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/health"
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/session-cookie-name: "neo-session"
      nginx.ingress.kubernetes.io/session-cookie-max-age: "10800"
    tls:
      - secretName: neo-api-tls-cert
        hosts:
          - api.neo.your-domain.com
```

### Amazon Web Services (AWS) EKS

**Option A: AWS Application Load Balancer (ALB) - Recommended**

For production EKS deployments, use ALB Ingress Controller with sticky sessions:

```yaml
api:
  service:
    type: ClusterIP
    port: 8000
    annotations:
      # ALB target group attributes
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "30"
      service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: "deregistration_delay.timeout_seconds=30"
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
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
      - secretName: neo-api-tls-cert
        hosts:
          - api.neo.your-domain.com

ui:
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    host: "neo.your-domain.com"
    className: "alb"
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/healthcheck-path: /
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: '443'
      alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id
    tls:
      - secretName: neo-ui-tls-cert
        hosts:
          - neo.your-domain.com
```

**Option B: nginx Ingress Controller with Service-level Session Affinity**

If using nginx Ingress Controller on EKS:

```yaml
api:
  service:
    type: ClusterIP
    port: 8000
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/session-cookie-name: "neo-session"
      nginx.ingress.kubernetes.io/session-cookie-max-age: "10800"
    tls:
      - secretName: neo-api-tls-cert
        hosts:
          - api.neo.your-domain.com
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
  name: {{ .Values.api.name }}-backend-config
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
    port: {{ .Values.api.env.PORT }}
```

Then configure your values.yaml:

```yaml
api:
  service:
    type: ClusterIP
    port: 8000
    annotations:
      cloud.google.com/neg: '{"ingress": true}'
      cloud.google.com/backend-config: '{"default": "neo-api-backend-config"}'
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
    className: "gce"
    annotations:
      # GCP-specific annotations
      kubernetes.io/ingress.class: "gce"
      kubernetes.io/ingress.global-static-ip-name: "neo-api-static-ip"

      # Managed SSL certificates
      networking.gke.io/managed-certificates: "neo-api-managed-cert"

      # Backend configuration with session affinity
      cloud.google.com/backend-config: '{"default": "neo-api-backend-config"}'

      # Optional: Cloud Armor for WAF protection
      # cloud.google.com/armor-config: '{"default": "neo-security-policy"}'

      # Network Endpoint Groups for better performance
      cloud.google.com/neg: '{"ingress": true}'
    tls:
      - secretName: neo-api-tls-cert
        hosts:
          - api.neo.your-domain.com

ui:
  service:
    type: ClusterIP
    port: 80
    annotations:
      cloud.google.com/neg: '{"ingress": true}'
  ingress:
    enabled: true
    host: "neo.your-domain.com"
    className: "gce"
    annotations:
      kubernetes.io/ingress.class: "gce"
      kubernetes.io/ingress.global-static-ip-name: "neo-ui-static-ip"
      networking.gke.io/managed-certificates: "neo-ui-managed-cert"
      cloud.google.com/neg: '{"ingress": true}'
    tls:
      - secretName: neo-ui-tls-cert
        hosts:
          - neo.your-domain.com
```

Create a ManagedCertificate resource (add to templates/neo-managed-cert.yaml):

```yaml
{{- if and .Values.api.ingress.enabled (eq .Values.api.ingress.className "gce") }}
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: neo-api-managed-cert
  namespace: {{ .Release.Namespace }}
spec:
  domains:
    - {{ .Values.api.ingress.host }}
{{- end }}
```

**Option B: nginx Ingress Controller with Service-level Session Affinity**

If using nginx Ingress Controller on GKE:

```yaml
api:
  service:
    type: ClusterIP
    port: 8000
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
    annotations:
      cloud.google.com/neg: '{"ingress": true}'
  ingress:
    enabled: true
    host: "api.neo.your-domain.com"
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/session-cookie-name: "neo-session"
      nginx.ingress.kubernetes.io/session-cookie-max-age: "10800"
    tls:
      - secretName: neo-api-tls-cert
        hosts:
          - api.neo.your-domain.com
```

### Session Affinity Comparison

| Platform | Recommended Approach | Timeout | Survives Pod Scaling | Best For |
|----------|---------------------|---------|---------------------|----------|
| **Azure AKS** | Application Gateway cookie affinity | 3 hours | Yes | Production deployments with WAF |
| **AWS EKS** | ALB sticky sessions (app_cookie) | 3 hours | Yes | Production deployments with AWS integration |
| **GCP GKE** | BackendConfig CLIENT_IP_PORT_PROTO | 3 hours | Yes | Production deployments with GCP services |
| **Generic K8s** | nginx cookie affinity + Service ClientIP | 3 hours | Partial | Development and multi-cloud |

### Important Notes

> [!IMPORTANT]
> **Session Affinity Requirements:**
> - **Minimum timeout**: 1800 seconds (30 minutes) for file operations
> - **Recommended timeout**: 10800 seconds (3 hours) for long-running Microsoft Graph operations
> - **Never use**: 60 seconds or less - this will break active sessions
>
> When scaling API replicas (`.Values.api.replicaCount > 1`):
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

The chart implements a microservice architecture with automatic service discovery via Kubernetes DNS:

### Service Communication Map

- **UI to API**: UI nginx proxies `/api/*` requests to `http://neo-api:8000`. Configured via `NEO_API` environment variable in the UI deployment.
- **API to Worker**: API calls `http://neo-worker:8000` for connection test operations and task dispatching.
- **API to NER**: API calls `http://neo-ner:8000` for device configuration and NER status checks.
- **Worker to Extractor**: Worker calls `http://neo-extractor:8000` for content extraction from connected data sources.
- **Worker to NER**: Worker calls `http://neo-ner:8000` for named entity recognition on extracted content.
- **All Services to PostgreSQL**: All backend services connect to `neo-postgres:5432` via `DATABASE_URL` for shared database access.

### Service URL Configuration

Each service discovers its dependencies through environment variables:

```yaml
api:
  env:
    WORKER_SERVICE_URL: "http://neo-worker:8000"
    NER_SERVICE_URL: "http://neo-ner:8000"

worker:
  env:
    EXTRACTOR_SERVICE_URL: "http://neo-extractor:8000"
    NER_SERVICE_URL: "http://neo-ner:8000"
```

### Key Communication Features

1. **Nginx Reverse Proxy**: UI automatically proxies `/api/*` to the API service
2. **InitContainer**: API and Worker wait for database readiness before starting
3. **Auto-generated URLs**: Built-in PostgreSQL connection string created automatically for all services
4. **Service Discovery**: Kubernetes DNS for internal service-to-service communication
5. **Internal-only Services**: Worker, Extractor, and NER services are not exposed externally

## Upgrading the Chart

To upgrade an existing release, use `helm upgrade`. The `--reuse-values` flag is recommended to preserve your existing configuration, including secrets.

```sh
# 1. Update your local chart repository
helm repo update

# 2. Upgrade the release to a new version
helm upgrade netapp-neo innovation-labs/netapp-neo \
  --namespace netapp-neo \
  --reuse-values \
  --set api.image.tag="4.0.2" \
  --set worker.image.tag="4.0.2" \
  --set extractor.image.tag="4.0.2" \
  --set ner.image.tag="4.0.2" \
  --set ui.image.tag="3.2.2"
```

**Upgrading with a values file:**
```sh
helm upgrade netapp-neo innovation-labs/netapp-neo \
  --namespace netapp-neo \
  -f my-values.yaml
```

> [!WARNING]
> **Upgrading from v3 to v4**: This is a major architecture change from a monolithic backend to a microservice architecture. A fresh installation is recommended rather than an in-place upgrade. Back up your database before any migration. The database name has changed from `netappconnector` to `neo_connector`, and the single `main.*` values section has been replaced with separate `api.*`, `worker.*`, `extractor.*`, and `ner.*` sections.

## Uninstallation

To uninstall and delete the `netapp-neo` release:

```sh
helm uninstall netapp-neo --namespace netapp-neo
```

> [!WARNING]
> **Data Persistence Note:**
> If you enabled the built-in PostgreSQL (`postgresql.enabled: true`), the PersistentVolumeClaim (PVC) will remain after uninstallation to prevent accidental data loss.
>
> To completely remove all data:
> ```sh
> # List PVCs
> kubectl get pvc -n netapp-neo
>
> # Delete PostgreSQL PVC (this will delete all database data)
> kubectl delete pvc data-neo-postgres-0 -n netapp-neo
> ```

> [!NOTE]
> If using an external database, your data will remain intact as it's managed separately from the Helm chart.

## Configuration Parameters

### API Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `api.name` | The base name for API resources. | `neo-api` |
| `api.replicaCount` | Number of API pods to run. | `1` |
| `api.image.repository` | The API container image repository. | `ghcr.io/netapp/netapp-neo-api` |
| `api.image.tag` | The API container image tag. If empty, defaults to chart's `appVersion`. | `""` |
| `api.image.pullPolicy` | The image pull policy. | `Always` |
| `api.service.type` | The type of Kubernetes service to create for the API. | `ClusterIP` |
| `api.service.port` | The port exposed by the API service and container. | `8000` |
| `api.ingress.enabled` | If true, create an Ingress resource for the API. | `false` |
| `api.ingress.host` | The hostname for the API Ingress rule. | `nil` |
| `api.ingress.path` | The path for the API Ingress rule. | `/` |
| `api.ingress.pathType` | The path type for the Ingress rule. | `Prefix` |
| `api.ingress.className` | The `ingressClassName` to associate with the Ingress. | `""` |
| `api.ingress.annotations` | Annotations for the Ingress resource. | `{}` |
| `api.ingress.tls` | Ingress TLS configuration. | `[]` |
| `api.env.PORT` | The port the API application runs on. | `8000` |
| `api.env.PYTHONUNBUFFERED` | Python unbuffered output. | `1` |
| `api.env.DATABASE_URL` | Database connection URL. Auto-generated if `postgresql.enabled=true`. | `""` |
| `api.env.WORKER_SERVICE_URL` | URL for the Worker service. | `http://neo-worker:8000` |
| `api.env.NER_SERVICE_URL` | URL for the NER service. | `http://neo-ner:8000` |
| `api.env.JWT_SECRET_KEY` | Secret key for JWT token generation. | `""` |
| `api.env.MCP_OAUTH_ENABLED` | Enable MCP OAuth authentication. | `false` |

### Worker Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.name` | The base name for Worker resources. | `neo-worker` |
| `worker.replicaCount` | Number of Worker pods to run. | `1` |
| `worker.image.repository` | The Worker container image repository. | `ghcr.io/netapp/netapp-neo-worker` |
| `worker.image.tag` | The Worker container image tag. If empty, defaults to chart's `appVersion`. | `""` |
| `worker.image.pullPolicy` | The image pull policy. | `Always` |
| `worker.service.type` | The type of Kubernetes service to create for the Worker. | `ClusterIP` |
| `worker.service.port` | The port exposed by the Worker service. | `8000` |
| `worker.env.DATABASE_URL` | Database connection URL. Auto-generated if `postgresql.enabled=true`. | `""` |
| `worker.env.EXTRACTOR_SERVICE_URL` | URL for the Extractor service. | `http://neo-extractor:8000` |
| `worker.env.NER_SERVICE_URL` | URL for the NER service. | `http://neo-ner:8000` |
| `worker.env.MS_GRAPH_CLIENT_ID` | Microsoft Graph client ID. | `""` |
| `worker.env.MS_GRAPH_CLIENT_SECRET` | Microsoft Graph client secret. | `""` |
| `worker.env.MS_GRAPH_TENANT_ID` | Microsoft Graph tenant ID. | `""` |
| `worker.env.NUM_CRAWL_WORKERS` | Number of concurrent crawl workers. | `2` |
| `worker.env.NUM_UPLOAD_WORKERS` | Number of concurrent upload workers. | `2` |
| `worker.env.ACL_STRICT_MODE` | Enable strict ACL enforcement. | `false` |
| `worker.securityContext.capabilities` | Linux capabilities (SYS_ADMIN, DAC_READ_SEARCH required). | See values.yaml |

### Extractor Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `extractor.name` | The base name for Extractor resources. | `neo-extractor` |
| `extractor.replicaCount` | Number of Extractor pods to run. | `1` |
| `extractor.image.repository` | The Extractor container image repository. | `ghcr.io/netapp/netapp-neo-extractor` |
| `extractor.image.tag` | The Extractor container image tag. If empty, defaults to chart's `appVersion`. | `""` |
| `extractor.image.pullPolicy` | The image pull policy. | `Always` |
| `extractor.service.type` | The type of Kubernetes service to create for the Extractor. | `ClusterIP` |
| `extractor.service.port` | The port exposed by the Extractor service. | `8000` |
| `extractor.env.DATABASE_URL` | Database connection URL. Auto-generated if `postgresql.enabled=true`. | `""` |
| `extractor.env.ENCRYPTION_KEY` | Encryption key for stored credentials. | `""` |
| `extractor.env.EXTRACTOR_TIMEOUT` | Timeout for extraction operations (seconds). | `300` |
| `extractor.env.VLM_ENABLED` | Enable Vision Language Model for image extraction. | `false` |
| `extractor.env.VLM_ENDPOINT` | VLM service endpoint URL. | `""` |
| `extractor.securityContext.privileged` | Privileged mode (required for NFS/CIFS mounts). | `true` |

### NER Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ner.name` | The base name for NER resources. | `neo-ner` |
| `ner.replicaCount` | Number of NER pods to run. | `1` |
| `ner.image.repository` | The NER container image repository. | `ghcr.io/netapp/netapp-neo-ner` |
| `ner.image.tag` | The NER container image tag. If empty, defaults to chart's `appVersion`. | `""` |
| `ner.image.pullPolicy` | The image pull policy. | `Always` |
| `ner.service.type` | The type of Kubernetes service to create for the NER. | `ClusterIP` |
| `ner.service.port` | The port exposed by the NER service. | `8000` |
| `ner.env.NER_MODEL` | GLiNER2 model name or path. | `""` |
| `ner.env.NER_BATCH_SIZE` | Batch size for NER processing. | `8` |
| `ner.env.TOKENIZERS_PARALLELISM` | HuggingFace tokenizers parallelism setting. | `false` |
| `ner.resources.limits.nvidia.com/gpu` | Number of NVIDIA GPUs to allocate (optional). | `0` |
| `ner.resources.limits.amd.com/gpu` | Number of AMD GPUs to allocate (optional). | `0` |

### UI Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ui.name` | The base name for UI resources. | `neo-ui` |
| `ui.replicaCount` | Number of UI pods to run. | `1` |
| `ui.image.repository` | The UI container image repository. | `ghcr.io/beezy-dev/neo-ui-framework` |
| `ui.image.tag` | UI image tag. | `3.2.2` |
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
| `postgresql.name` | The name for PostgreSQL resources. | `neo-postgres` |
| `postgresql.image.repository` | PostgreSQL container image repository. | `docker.io/library/postgres` |
| `postgresql.image.tag` | PostgreSQL image tag. | `17` |
| `postgresql.image.pullPolicy` | PostgreSQL image pull policy. | `IfNotPresent` |
| `postgresql.auth.username` | PostgreSQL username. | `postgres` |
| `postgresql.auth.password` | PostgreSQL password. **Should be changed for production.** | `neodbsecret` |
| `postgresql.auth.database` | PostgreSQL database name. | `neo_connector` |
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
┌─────────────────────────────────────────────────────────────────┐
│                    External Access Layer                        │
│                    (Ingress Controller)                         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
   ┌──────────────────┐       ┌──────────────────┐
   │   UI Ingress     │       │  API Ingress     │
   │   (Optional)     │       │   (Optional)     │
   └────────┬─────────┘       └────────┬─────────┘
            │                          │
            ▼                          ▼
   ┌──────────────────┐       ┌──────────────────┐
   │   UI Service     │       │  API Service     │
   │   (ClusterIP)    │       │   (ClusterIP)    │
   │   Port: 80       │       │   Port: 8000     │
   └────────┬─────────┘       └────────┬─────────┘
            │                          │
            ▼                          ▼
   ┌──────────────────┐       ┌──────────────────┐
   │   UI Pod(s)      │──────▶│  API Pod(s)      │
   │   (nginx)        │       │  (FastAPI)       │
   │  /api/* → :8000  │       │  InitContainer   │
   │                  │       │  waits for DB    │
   └──────────────────┘       └───────┬──────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                  │
                    ▼                 ▼                  ▼
          ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
          │ Worker Svc   │  │ Extractor Svc│  │  NER Svc     │
          │ (ClusterIP)  │  │ (ClusterIP)  │  │ (ClusterIP)  │
          │ Port: 8000   │  │ Port: 8000   │  │ Port: 8000   │
          └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
                 │                 │                  │
                 ▼                 ▼                  ▼
          ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
          │ Worker Pod(s)│  │Extractor     │  │ NER Pod(s)   │
          │ (background  │  │Pod(s)        │  │ (GLiNER2)    │
          │  processing) │─▶│(content      │  │ Optional GPU │
          │              │  │ extraction)  │  │              │
          │              │─────────────────────▶              │
          └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
                 │                 │                  │
                 └─────────────────┼──────────────────┘
                                   │
                                   ▼
                        ┌──────────────────────────┐
                        │       Database           │
                        ├──────────────────────────┤
                        │ Option 1: Built-in       │
                        │ - PostgreSQL 17           │
                        │   StatefulSet            │
                        │ - PVC (10Gi default)     │
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

1. **Nginx Reverse Proxy**: UI automatically proxies `/api/*` to the API service
2. **InitContainer**: Waits for database readiness before starting backend services
3. **Auto-generated URLs**: Built-in PostgreSQL connection string created automatically for all services
4. **Service Discovery**: Kubernetes DNS for internal service-to-service communication
5. **Internal Services**: Worker, Extractor, and NER are cluster-internal only (no Ingress)
6. **GPU Scheduling**: NER pods are scheduled to GPU nodes when GPU resources are requested

## Troubleshooting

### Check Pod Status

```sh
kubectl get pods -n netapp-neo
```

Expected output:
```
NAME                              READY   STATUS    RESTARTS   AGE
neo-api-xxxx                      1/1     Running   0          5m
neo-worker-xxxx                   1/1     Running   0          5m
neo-extractor-xxxx                1/1     Running   0          5m
neo-ner-xxxx                      1/1     Running   0          5m
neo-ui-xxxx                       1/1     Running   0          5m
neo-postgres-0                    1/1     Running   0          5m
```

### View Service Logs

```sh
# View API service logs
kubectl logs -n netapp-neo -l component=neo-api -f

# View Worker service logs
kubectl logs -n netapp-neo -l component=neo-worker -f

# View Extractor service logs
kubectl logs -n netapp-neo -l component=neo-extractor -f

# View NER service logs
kubectl logs -n netapp-neo -l component=neo-ner -f

# View initContainer logs (database wait)
kubectl logs -n netapp-neo -l component=neo-api -c wait-for-db
```

### View UI Logs

```sh
kubectl logs -n netapp-neo -l component=neo-ui -f
```

### View PostgreSQL Logs (if enabled)

```sh
kubectl logs -n netapp-neo -l component=neo-postgres -f
```

### Test API Connectivity from UI Pod

```sh
kubectl exec -n netapp-neo -it deployment/neo-ui -- curl http://neo-api:8000/health
```

### Verify Inter-Service Connectivity

```sh
# Test API to Worker
kubectl exec -n netapp-neo -it deployment/neo-api -- curl http://neo-worker:8000/health

# Test Worker to Extractor
kubectl exec -n netapp-neo -it deployment/neo-worker -- curl http://neo-extractor:8000/health

# Test Worker to NER
kubectl exec -n netapp-neo -it deployment/neo-worker -- curl http://neo-ner:8000/health
```

### Verify Database Connection

```sh
# Check DATABASE_URL (sensitive - be careful in production)
kubectl exec -n netapp-neo -it deployment/neo-api -- env | grep DATABASE_URL

# Test PostgreSQL connection (built-in)
kubectl exec -n netapp-neo -it statefulset/neo-postgres -- pg_isready -U postgres
```

### Test PostgreSQL Connection (if built-in PostgreSQL is enabled)

```sh
# Get PostgreSQL password
PGPASSWORD=$(kubectl get secret neo-postgres-secret -n netapp-neo -o jsonpath='{.data.password}' | base64 -d)

# Connect to PostgreSQL
kubectl exec -it -n netapp-neo statefulset/neo-postgres -- psql -U postgres -d neo_connector

# Run a test query
\dt  # List tables
\q   # Quit
```

### Check PostgreSQL PVC Status

```sh
kubectl get pvc -n netapp-neo
kubectl describe pvc data-neo-postgres-0 -n netapp-neo
```

### Verify ConfigMaps and Secrets

```sh
# Check ConfigMaps
kubectl get configmap -n netapp-neo
kubectl get configmap neo-api -n netapp-neo -o yaml

# Check Secrets (base64 encoded)
kubectl get secret neo-api -n netapp-neo -o yaml

# Decode a specific secret value
kubectl get secret neo-worker -n netapp-neo -o jsonpath='{.data.MS_GRAPH_CLIENT_ID}' | base64 -d
```

### Common Issues

#### 1. PostgreSQL Pod Not Starting

**Symptom**: `neo-postgres-0` pod stuck in `Pending` or `Init` state

**Solutions**:

```sh
# Check PVC status
kubectl get pvc -n netapp-neo
kubectl describe pvc data-neo-postgres-0 -n netapp-neo

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

#### 2. API Cannot Connect to Database

**Symptom**: API pod shows database connection errors in logs

**Solutions**:

```sh
# 1. Verify PostgreSQL service exists
kubectl get svc neo-postgres -n netapp-neo

# 2. Check DATABASE_URL format
kubectl get secret neo-api -n netapp-neo -o jsonpath='{.data.DATABASE_URL}' | base64 -d

# 3. Test database connectivity from API pod
kubectl exec -n netapp-neo -it deployment/neo-api -- nc -zv neo-postgres 5432

# 4. Check PostgreSQL readiness
kubectl exec -n netapp-neo -it statefulset/neo-postgres -- pg_isready -U postgres
```

#### 3. InitContainer Stuck Waiting for Database

**Symptom**: API or Worker pod shows `Init:0/1` status

**Solutions**:

```sh
# Check initContainer logs
kubectl logs -n netapp-neo -l component=neo-api -c wait-for-db

# Check PostgreSQL pod status
kubectl describe pod -n netapp-neo neo-postgres-0

# Verify PostgreSQL credentials match
kubectl get secret neo-postgres-secret -n netapp-neo -o jsonpath='{.data.password}' | base64 -d
kubectl get secret neo-api -n netapp-neo -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

#### 4. UI Cannot Reach API Service

**Symptom**: UI loads but API calls fail with 502/503 errors

**Solutions**:

```sh
# 1. Verify API service
kubectl get svc neo-api -n netapp-neo

# 2. Test from UI pod
kubectl exec -n netapp-neo -it deployment/neo-ui -- curl -v http://neo-api:8000/health

# 3. Check nginx proxy configuration
kubectl exec -n netapp-neo -it deployment/neo-ui -- cat /etc/nginx/conf.d/default.conf

# 4. Check NEO_API environment variable
kubectl exec -n netapp-neo -it deployment/neo-ui -- env | grep NEO_API
```

#### 5. Worker Cannot Reach Extractor or NER

**Symptom**: Crawl jobs fail with connection errors to extractor or NER service

**Solutions**:

```sh
# 1. Verify services exist
kubectl get svc neo-extractor neo-ner -n netapp-neo

# 2. Test from Worker pod
kubectl exec -n netapp-neo -it deployment/neo-worker -- curl -v http://neo-extractor:8000/health
kubectl exec -n netapp-neo -it deployment/neo-worker -- curl -v http://neo-ner:8000/health

# 3. Check Worker environment variables
kubectl exec -n netapp-neo -it deployment/neo-worker -- env | grep SERVICE_URL
```

#### 6. Extractor Fails with Permission Errors

**Symptom**: Extractor pod cannot mount NFS/CIFS shares

**Solutions**:

```sh
# 1. Verify the Extractor pod is running in privileged mode
kubectl get pod -n netapp-neo -l component=neo-extractor -o jsonpath='{.items[0].spec.containers[0].securityContext}'

# 2. Check pod security policies or admission controllers
kubectl describe pod -n netapp-neo -l component=neo-extractor

# 3. Ensure cluster allows privileged containers
```

#### 7. NER GPU Not Detected

**Symptom**: NER service running on CPU despite GPU configuration

**Solutions**:

```sh
# 1. Verify GPU nodes are available
kubectl get nodes -l nvidia.com/gpu.present=true

# 2. Check NER pod resource requests
kubectl describe pod -n netapp-neo -l component=neo-ner

# 3. Verify nvidia-container-toolkit is installed
kubectl get pods -n kube-system | grep nvidia

# 4. Check NER logs for GPU detection
kubectl logs -n netapp-neo -l component=neo-ner | grep -i gpu
```

#### 8. Cloud-Specific Issues

**Azure Application Gateway Ingress Controller (AGIC) not working**:

```sh
# Check AGIC pod status
kubectl get pods -n kube-system | grep ingress-azure

# Verify Ingress annotations
kubectl describe ingress -n netapp-neo

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
kubectl describe ingress -n netapp-neo
kubectl describe svc neo-ui -n netapp-neo

# Check AWS Load Balancer status
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `netapp-neo`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}'
```

**Azure Database for PostgreSQL connection issues**:

```sh
# Ensure SSL is required in connection string
DATABASE_URL: "postgresql://user@server:pass@server.postgres.database.azure.com:5432/neo_connector?sslmode=require"

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
DATABASE_URL: "postgresql://user:pass@instance.xxxxx.us-east-1.rds.amazonaws.com:5432/neo_connector?sslmode=require"

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
api:
  env:
    PYTHONUNBUFFERED: "1"  # Enable immediate log output

worker:
  env:
    PYTHONUNBUFFERED: "1"

extractor:
  env:
    PYTHONUNBUFFERED: "1"

ner:
  env:
    PYTHONUNBUFFERED: "1"
```

View real-time logs:
```sh
# API
kubectl logs -n netapp-neo -l component=neo-api -f --tail=100

# Worker
kubectl logs -n netapp-neo -l component=neo-worker -f --tail=100

# Extractor
kubectl logs -n netapp-neo -l component=neo-extractor -f --tail=100

# NER
kubectl logs -n netapp-neo -l component=neo-ner -f --tail=100

# UI
kubectl logs -n netapp-neo -l component=neo-ui -f --tail=100

# PostgreSQL
kubectl logs -n netapp-neo -l component=neo-postgres -f --tail=100
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
  --version 17 \
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
  --policy-name NetAppNeoRDSPolicy \
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
  --name netapp-neo-sa \
  --namespace netapp-neo \
  --cluster myEKSCluster \
  --attach-policy-arn arn:aws:iam::123456789012:policy/NetAppNeoRDSPolicy \
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
  --db-instance-identifier netapp-neo-db \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 17 \
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
  --db-instance-identifier netapp-neo-db \
  --backup-retention-period 30 \
  --apply-immediately
```

**Using Amazon Aurora PostgreSQL (recommended for high availability):**

```sh
# Create Aurora PostgreSQL cluster
aws rds create-db-cluster \
  --db-cluster-identifier netapp-neo-cluster \
  --engine aurora-postgresql \
  --engine-version 17 \
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
  --db-instance-identifier netapp-neo-instance-1 \
  --db-cluster-identifier netapp-neo-cluster \
  --db-instance-class db.r6g.large \
  --engine aurora-postgresql \
  --region us-east-1
```
