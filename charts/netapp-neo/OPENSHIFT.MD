# Deploy NetApp Neo on OpenShift

This guide describes how to deploy this chart on OpenShift with the new security model:

- Restricted-v2 baseline for the application
- Mandatory privileged exceptions for `worker` and `extractor` to access remote file systems
- Helm validation enforces this mode during render/install

## 1. Prerequisites

- OpenShift cluster access (`oc`)
- Helm 3
- Cluster admin support for SCC binding (required for privileged worker/extractor mode)
- Target namespace exists

Examples used in this guide:

- `<release>` example: `netapp-neo`
- `<namespace>` example: `neo-poc`

Select your target namespace:

```bash
oc project <namespace>
```

Prepare OpenShift values override file:

```bash
cat > values-openshift.yaml <<'EOF'
openshift:
  enabled: true
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
EOF
```

## 2. Deployment Mode

### Restricted-v2 + privileged exceptions (worker/extractor)

This is the required deployment mode for this application because `worker` and `extractor`
must mount filesystems inside the pod.

Required chart behavior:

- `openshift.enabled=true`
- `openshift.restrictedV2.enabled=true`
- `openshift.privilegedWorkloads.worker.enabled=true`
- `openshift.privilegedWorkloads.extractor.enabled=true`

These are enforced by chart validation. Helm will fail if any are set to `false`.

Deploy:

```bash
helm upgrade --install <release> innovation-labs/netapp-neo \
  -n <namespace> \
  -f ./values.yaml \
  -f ./values-openshift.yaml \
  --wait --timeout 10m --rollback-on-failure
```

If you maintain a platform-specific values file, keep this OpenShift block there.

## 3. Bind SCC for Privileged Exception Service Accounts

Service account names are derived from the Helm release name and can also be affected by `fullnameOverride`.

In this mode, the chart creates service accounts like:

- `<release>-netapp-neo-api`
- `<release>-netapp-neo-ui`
- `<release>-netapp-neo-worker-privileged`
- `<release>-netapp-neo-extractor-privileged`

Bind an SCC that permits required behavior (example shown with `privileged`; use a narrower custom SCC if possible):

```bash
# Replace <release> and namespace with your values.
oc adm policy add-scc-to-user privileged \
  -z <release>-netapp-neo-worker-privileged \
  -n <namespace>

oc adm policy add-scc-to-user privileged \
  -z <release>-netapp-neo-extractor-privileged \
  -n <namespace>
```

If you set custom service account names in values:

- `openshift.api.serviceAccount.name`
- `openshift.ui.serviceAccount.name`
- `openshift.privilegedWorkloads.worker.serviceAccount.name`
- `openshift.privilegedWorkloads.extractor.serviceAccount.name`

use those names in the `oc adm policy` commands.

If you set `serviceAccount.create=false`, ensure those service accounts already exist in the namespace.

## 4. Verify Deployment

Check pods:

```bash
oc get pods -n <namespace>
```

Check service account used by api/ui/worker/extractor:

```bash
# Replace <release> and namespace with your values.
oc get deploy <release>-netapp-neo-api -n <namespace> -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
oc get deploy <release>-netapp-neo-ui -n <namespace> -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
oc get deploy <release>-netapp-neo-worker -n <namespace> -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
oc get deploy <release>-netapp-neo-extractor -n <namespace> -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
```

Check events for SCC admission issues:

```bash
oc get events -n <namespace> --sort-by=.lastTimestamp | tail -n 50
```

Confirm API deployment does not render forbidden fixed IDs or explicit seccomp:

```bash
# Replace <release> and namespace with your values.
oc get deploy <release>-netapp-neo-api -n <namespace> -o yaml | grep -E "runAsUser|runAsGroup|fsGroup|seccompProfile" -n
```

## 5. Troubleshooting

If pods are blocked by SCC:

- Confirm privileged exception flags are enabled as required.
- Confirm SCC binding exists for the exact service account names.
- Confirm namespace in `oc adm policy` matches deployment namespace.
- Confirm api/ui/worker/extractor serviceAccountName values in the live deployment are the expected service accounts.
- Confirm worker/extractor service accounts are the ones bound to SCC.
- Re-run Helm with `--wait --rollback-on-failure` to catch rollout failures clearly.

Example inspection:

```bash
oc describe rs -n <namespace> | grep -E "forbidden|security context constraint|SCC|restricted-v2" -i
```

## 6. Recommended Operational Practice

- Keep this single enforced mode for OpenShift deployments.
- Keep API and UI on dedicated non-privileged service accounts.
- Grant elevated SCC only to `worker` and `extractor` service accounts.
- Prefer a custom least-privilege SCC over broad `privileged` SCC when feasible.
