# Deploy NetApp Neo on OpenShift

This guide describes how to deploy this chart on OpenShift with the security model:

- A single master switch (`openshift.deploy`) turns on all OpenShift-specific behavior
- Restricted-v2 baseline for the application
- Mandatory privileged exceptions for `worker` and `extractor` to access remote file systems
- Automated SCC binding: the chart ships namespaced `RoleBinding`s, so no manual `oc adm policy` step is required
- Postgres runs under the `anyuid` SCC so the official image works with its built-in UID
- Helm validation enforces this mode during render/install

## 1. Prerequisites

- OpenShift cluster access (`oc`)
- Helm 3
- Permission to create `RoleBinding`s in the target namespace (namespace admin is sufficient;
  cluster admin is not required because the chart binds existing `system:openshift:scc:*` ClusterRoles)
- Target namespace exists, example: `neo-poc`

Select your target namespace:

```bash
oc project neo-poc
```

Prepare OpenShift values override file:

```bash
cat > values-openshift.yaml <<'EOF'
openshift:
  # Master switch: enables all OpenShift-specific behavior below.
  deploy: true
  restrictedV2:
    enabled: true
  api:
    serviceAccount:
      create: true
      name: ""
      annotations: {}
  ui:
    serviceAccount:
      create: true
      name: ""
      annotations: {}
  privilegedWorkloads:
    # Automatically create RoleBindings granting the worker/extractor SAs use of
    # the named SCC (replaces the manual `oc adm policy add-scc-to-user` step).
    bindSCC: true
    sccName: privileged
    worker:
      enabled: true
      serviceAccount:
        create: true
        name: ""
        annotations: {}
    extractor:
      enabled: true
      serviceAccount:
        create: true
        name: ""
        annotations: {}
  # Postgres needs anyuid (not restricted-v2) so the official image can run as its
  # built-in UID instead of a random injected one.
  postgres:
    bindAnyuid: true
    sccName: anyuid
    serviceAccount:
      create: true
      name: ""
      annotations: {}
EOF
```

> Setting `openshift.deploy=false` disables every OpenShift-specific resource
> (SCC RoleBindings, dedicated service accounts, restricted-v2 security contexts),
> which is the correct mode for vanilla Kubernetes.

## 2. Deployment Mode

### Restricted-v2 + privileged exceptions (worker/extractor)

This is the required deployment mode for this application because `worker` and `extractor`
must mount filesystems inside the pod.

Required chart behavior:

- `openshift.deploy=true`
- `openshift.restrictedV2.enabled=true`
- `openshift.privilegedWorkloads.worker.enabled=true`
- `openshift.privilegedWorkloads.extractor.enabled=true`

These are enforced by chart validation. Helm will fail if any are set to `false` while `openshift.deploy=true`.

Deploy:

```bash
helm upgrade --install netapp-neo innovation-labs/netapp-neo \
  -n neo-poc \
  -f ./netapp-neo/values.yaml \
  -f ./values-openshift.yaml \
  --wait --timeout 10m --rollback-on-failure
```

If you maintain a platform-specific values file, keep this OpenShift block there.

## 3. SCC Binding (Automated)

With `openshift.deploy=true`, the chart creates these service accounts:

- `netapp-neo-netapp-neo-api`
- `netapp-neo-netapp-neo-ui`
- `netapp-neo-netapp-neo-worker-privileged`
- `netapp-neo-netapp-neo-extractor-privileged`
- `netapp-neo-netapp-neo-postgres`

It also ships namespaced `RoleBinding`s that grant each privileged SA use of the
required SCC, so **no manual `oc adm policy` step is needed**:

| Service account | Bound SCC | Controlled by |
| --- | --- | --- |
| `...-worker-privileged` | `openshift.privilegedWorkloads.sccName` (default `privileged`) | `openshift.privilegedWorkloads.bindSCC` |
| `...-extractor-privileged` | `openshift.privilegedWorkloads.sccName` (default `privileged`) | `openshift.privilegedWorkloads.bindSCC` |
| `...-postgres` | `openshift.postgres.sccName` (default `anyuid`) | `openshift.postgres.bindAnyuid` |

These bindings reference the built-in `system:openshift:scc:<name>` ClusterRoles, so a
namespace admin can apply them (cluster admin not required).

Verify the bindings were created:

```bash
oc get rolebinding -n neo-poc | grep -E "worker-scc|extractor-scc|postgres-scc"
```

### Manual fallback

If you prefer to manage SCC access yourself, set `openshift.privilegedWorkloads.bindSCC=false`
and `openshift.postgres.bindAnyuid=false`, then bind SCCs manually:

```bash
oc adm policy add-scc-to-user privileged \
  -z netapp-neo-netapp-neo-worker-privileged \
  -n neo-poc

oc adm policy add-scc-to-user privileged \
  -z netapp-neo-netapp-neo-extractor-privileged \
  -n neo-poc

oc adm policy add-scc-to-user anyuid \
  -z netapp-neo-netapp-neo-postgres \
  -n neo-poc
```

If you set custom service account names in values:

- `openshift.api.serviceAccount.name`
- `openshift.ui.serviceAccount.name`
- `openshift.privilegedWorkloads.worker.serviceAccount.name`
- `openshift.privilegedWorkloads.extractor.serviceAccount.name`
- `openshift.postgres.serviceAccount.name`

the chart uses those names for both the SAs and the generated RoleBindings.

If you set `serviceAccount.create=false`, ensure those service accounts already exist in the namespace.

## 4. Verify Deployment

Check pods:

```bash
oc get pods -n neo-poc
```

Check service account used by api/ui/worker/extractor:

```bash
oc get deploy netapp-neo-netapp-neo-api -n neo-poc -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
oc get deploy netapp-neo-netapp-neo-ui -n neo-poc -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
oc get deploy netapp-neo-netapp-neo-worker -n neo-poc -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
oc get deploy netapp-neo-netapp-neo-extractor -n neo-poc -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
```

Check events for SCC admission issues:

```bash
oc get events -n neo-poc --sort-by=.lastTimestamp | tail -n 50
```

Confirm API deployment does not render forbidden fixed IDs or explicit seccomp:

```bash
oc get deploy netapp-neo-netapp-neo-api -n neo-poc -o yaml | grep -E "runAsUser|runAsGroup|fsGroup|seccompProfile" -n
```

Confirm Postgres is running and reachable (init containers in other pods wait on it):

```bash
oc get pods -n neo-poc -l app.kubernetes.io/component=postgres
oc get statefulset netapp-neo-netapp-neo-postgres -n neo-poc -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
```

Confirm inter-service URLs are injected (API calls worker/ner; worker calls extractor/ner):

```bash
oc get configmap netapp-neo-netapp-neo-api -n neo-poc -o yaml | grep -E "WORKER_SERVICE_URL|NER_SERVICE_URL"
oc get configmap netapp-neo-netapp-neo-worker -n neo-poc -o yaml | grep -E "EXTRACTOR_SERVICE_URL|NER_SERVICE_URL"
```

## 5. Troubleshooting

If pods are blocked by SCC:

- Confirm `openshift.deploy=true` and the privileged exception flags are enabled as required.
- Confirm the generated RoleBindings exist (`oc get rolebinding -n neo-poc | grep scc`); if `bindSCC`/`bindAnyuid` are false, confirm your manual `oc adm policy` bindings.
- Confirm SCC binding exists for the exact service account names.
- Confirm namespace in the RoleBindings (or `oc adm policy`) matches the deployment namespace.
- Confirm api/ui/worker/extractor/postgres serviceAccountName values in the live workloads are the expected service accounts.

If Postgres never becomes Ready (and other pods hang in `Init`):

- Confirm the `...-postgres` SA is bound to the `anyuid` SCC.
- Confirm `postgresql.podSecurityContext.fsGroup` matches the image group (70 for the alpine image).
- Check the postgres pod logs for permission errors on `/var/lib/postgresql/data`.

Example inspection:

```bash
oc describe rs -n neo-poc | grep -E "forbidden|security context constraint|SCC|restricted-v2" -i
```

## 6. Recommended Operational Practice

- Keep this single enforced mode for OpenShift deployments.
- Keep API and UI on dedicated non-privileged service accounts.
- Grant elevated SCC only to `worker` and `extractor` service accounts.
- Keep Postgres on its own `anyuid`-bound service account, separate from the privileged workloads.
- Prefer a custom least-privilege SCC over broad `privileged` SCC when feasible (set `openshift.privilegedWorkloads.sccName`).
- Use `openshift.deploy=false` for vanilla Kubernetes; it disables all OpenShift-only resources.
