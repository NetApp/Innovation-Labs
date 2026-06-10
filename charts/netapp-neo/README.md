# NetApp Neo Helm Chart

NetApp Neo v4.x — a context lake microservice architecture that exposes AI services via MCP.

This chart deploys the full Neo stack:

| Component | Description | Default |
| --- | --- | --- |
| `api` | Public API / MCP entrypoint | enabled |
| `worker` | Orchestration workers (calls extractor/ner) | enabled |
| `extractor` | Document/file extractor (mounts remote filesystems) | enabled |
| `ner` | Named-entity recognition service (optional, GPU-capable) | disabled |
| `ui` | Neo web UI | enabled |
| `postgresql` | Bundled PostgreSQL database | enabled |

The chart supports two deployment targets from a single switch:

- **Vanilla Kubernetes** — `openshift.deploy=false`
- **OpenShift** — `openshift.deploy=true` (restricted-v2 baseline + privileged exceptions for `worker`/`extractor`, automated SCC binding)

---

## Prerequisites

- Kubernetes 1.25+ or OpenShift 4.12+
- Helm 3
- A default `StorageClass` (or set `postgresql.persistence.storageClass`) for the bundled database
- `kubectl` (Kubernetes) or `oc` (OpenShift)

---

## Vanilla Kubernetes Deployment

On plain Kubernetes, disable the OpenShift-specific behavior. Workloads then run
with explicit `runAsUser`/`fsGroup` security contexts and no SCC RoleBindings or
dedicated service accounts are created.

```bash
helm upgrade --install netapp-neo ./netapp-neo \
  -n neo \
  --create-namespace \
  --set openshift.deploy=false \
  --wait --timeout 10m
```

Verify:

```bash
kubectl get pods -n neo
kubectl get svc -n neo
```

To expose the API and UI, enable their ingresses:

```bash
helm upgrade --install netapp-neo ./netapp-neo \
  -n neo \
  --set openshift.deploy=false \
  --set api.ingress.enabled=true --set api.ingress.host=neo-api.example.com \
  --set ui.ingress.enabled=true  --set ui.ingress.host=neo.example.com
```

---

## OpenShift Deployment

On OpenShift the chart enforces a restricted-v2 baseline, grants `worker` and
`extractor` privileged exceptions (they mount remote filesystems), runs Postgres
under the `anyuid` SCC, and **automatically creates the SCC RoleBindings** — no
manual `oc adm policy` step is required.

Select the namespace:

```bash
oc new-project neo-poc   # or: oc project neo-poc
```

Deploy (defaults already target OpenShift, `openshift.deploy=true`):

```bash
helm upgrade --install netapp-neo ./netapp-neo \
  -n neo-poc \
  --wait --timeout 10m --rollback-on-failure
```

The installer must be able to create `RoleBinding`s in the namespace
(namespace admin is sufficient — cluster admin is **not** required).

Verify:

```bash
oc get pods -n neo-poc
oc get rolebinding -n neo-poc | grep scc
```

For full OpenShift details (service accounts, SCC mapping, manual fallback,
troubleshooting), see [OPENSHIFT.MD](OPENSHIFT.MD).

---

## Common Configuration

### Database

The chart bundles PostgreSQL by default. To use an external database instead:

```yaml
postgresql:
  enabled: false
  externalDatabaseUrl: "postgresql://user:pass@host:5432/neodb"
```

### Enable the NER service

```bash
--set ner.enabled=true
# GPU scheduling (optional):
--set ner.gpu.enabled=true --set ner.gpu.count=1
```

### Images

All services pull from `ghcr.io/netapp/*`. Image tags default to the chart
`appVersion`; override per service with `<service>.image.tag`. Add registry
credentials via `imagePullSecrets`.

---

## Key Values

| Value | Default | Description |
| --- | --- | --- |
| `openshift.deploy` | `true` | Master switch: `true` for OpenShift, `false` for vanilla Kubernetes |
| `openshift.restrictedV2.enabled` | `true` | Use the restricted-v2 SCC baseline (OpenShift) |
| `openshift.privilegedWorkloads.bindSCC` | `true` | Auto-create SCC RoleBindings for worker/extractor |
| `openshift.privilegedWorkloads.sccName` | `privileged` | SCC bound to worker/extractor |
| `openshift.postgres.bindAnyuid` | `true` | Bind the Postgres SA to the `anyuid` SCC |
| `postgresql.enabled` | `true` | Deploy the bundled PostgreSQL |
| `postgresql.persistence.size` | `8Gi` | Database volume size |
| `ner.enabled` | `false` | Deploy the NER service |
| `api.ingress.enabled` | `false` | Expose the API via Ingress |
| `ui.ingress.enabled` | `false` | Expose the UI via Ingress |

See [values.yaml](values.yaml) for the complete list.

---

## Uninstall

```bash
helm uninstall netapp-neo -n <namespace>
```

PersistentVolumeClaims created by the StatefulSet are retained by default; delete
them manually if you want to remove the database data:

```bash
kubectl delete pvc -l app.kubernetes.io/component=postgres -n <namespace>
```
