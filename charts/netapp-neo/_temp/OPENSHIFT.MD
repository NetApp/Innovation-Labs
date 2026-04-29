# Deploy NetApp Neo on OpenShift

This guide describes how to deploy this chart on OpenShift with the new security model:

- Restricted mode by default (compatible with `restricted-v2` SCC)
- Explicit privileged exceptions for `worker` and `extractor` only when needed for filesystem mount operations

## 1. Prerequisites

- OpenShift cluster access (`oc`)
- Helm 3
- Cluster admin support for SCC binding (required only for privileged worker/extractor mode)
- Target namespace exists, example: `neo-poc`

```bash
oc project neo-poc
```

## 2. Security Modes

### Mode A: Restricted by default (recommended)

Use this when `worker` and `extractor` do not require elevated mount operations.

Default chart behavior:

- `openshift.restrictedV2.enabled=true`
- `openshift.privilegedWorkloads.worker.enabled=false`
- `openshift.privilegedWorkloads.extractor.enabled=false`

Deploy:

```bash
helm upgrade --install netapp-neo . \
  -n neo-poc \
  -f values.yaml \
  -f _temp/values-openshift-restricted.yaml \
  --wait --timeout 10m --rollback-on-failure
```

### Mode B: Restricted + privileged exceptions (worker/extractor)

Use this when `worker` and `extractor` must mount filesystems inside the pod.

Enable exceptions during deploy:

```bash
helm upgrade --install netapp-neo . \
  -n neo-poc \
  -f values.yaml \
  -f _temp/values-openshift-privileged.yaml \
  --wait --timeout 10m --rollback-on-failure
```

Companion values files:

- `_temp/values-openshift-restricted.yaml`
- `_temp/values-openshift-privileged.yaml`

## 3. Bind SCC for Privileged Exception Service Accounts

When Mode B is enabled, the chart creates dedicated service accounts:

- `netapp-neo-netapp-neo-worker-privileged`
- `netapp-neo-netapp-neo-extractor-privileged`

Bind an SCC that permits required behavior (example shown with `privileged`; use a narrower custom SCC if possible):

```bash
oc adm policy add-scc-to-user privileged \
  -z netapp-neo-netapp-neo-worker-privileged \
  -n neo-poc

oc adm policy add-scc-to-user privileged \
  -z netapp-neo-netapp-neo-extractor-privileged \
  -n neo-poc
```

If you set custom service account names in values:

- `openshift.privilegedWorkloads.worker.serviceAccount.name`
- `openshift.privilegedWorkloads.extractor.serviceAccount.name`

use those names in the `oc adm policy` commands.

## 4. Verify Deployment

Check pods:

```bash
oc get pods -n neo-poc
```

Check service account used by worker/extractor:

```bash
oc get deploy netapp-neo-netapp-neo-worker -n neo-poc -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
oc get deploy netapp-neo-netapp-neo-extractor -n neo-poc -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
```

Check events for SCC admission issues:

```bash
oc get events -n neo-poc --sort-by=.lastTimestamp | tail -n 50
```

## 5. Troubleshooting

If pods are blocked by SCC:

- Confirm privileged exception flags were set as expected.
- Confirm SCC binding exists for the exact service account names.
- Confirm namespace in `oc adm policy` matches deployment namespace.
- Re-run Helm with `--wait --rollback-on-failure` to catch rollout failures clearly.

Example inspection:

```bash
oc describe rs -n neo-poc | grep -E "forbidden|security context constraint|SCC|restricted-v2" -i
```

## 6. Recommended Operational Practice

- Keep restricted mode as default.
- Grant elevated SCC only to `worker` and `extractor` service accounts.
- Prefer a custom least-privilege SCC over broad `privileged` SCC when feasible.
