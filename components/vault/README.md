# Vault on OpenShift (vSphere) via OpenShift GitOps

> **WARNING:** Rebuilds can cause irreversible data loss if you delete Raft PVCs. Backup before nuking.

## What you get
- HA Vault on Raft, OpenShift-safe (non-root, `VAULT_DISABLE_MLOCK=true`)
- Injector enabled, K8s auth pre-wired
- NetworkPolicies (default deny with allowlists)
- Optional OpenShift Route
- Bootstrap hook to init/unseal and configure auth without leaking secrets to logs
- SOPS (age) setup for secure handling of bootstrap bundle
- ACM-friendly pattern to offload/retain root token & unseal keys

## Prereqs
- OpenShift GitOps (Argo CD) in `openshift-gitops`
- vSphere CSI StorageClass — set in `values.openshift.yaml`
- Optional: cert-manager for Route TLS reencrypt
- SOPS (age) locally for operators. If you want Argo to decrypt, install KSOPS or use builtin SOPS in OpenShift GitOps.
- (Optional) ACM hub reachable by operators (or provide `bootstrap.acmPushURL`)

## Deploy
1. Edit:
   - `helm/values.openshift.yaml`: set `storageClass`, Route `host` if exposing UI/API.
   - `helm/values.yaml`: set `.bootstrap.agePublicKey`.
2. Commit/push repo so `$values/` paths resolve.
3. Apply Argo CD app:
   ```bash
   oc apply -f platform/vault/argocd-app.yaml -n openshift-gitops
   ```
4. Sync the app. Wait for `vault-0` to be Ready.

## Bootstrap (secure handling)

- The hook job runs and prints a SOPS-encrypted Secret manifest between:

```
-----BEGIN VAULT-BOOTSTRAP-SECRET-----
...
-----END VAULT-BOOTSTRAP-SECRET-----
```
- Copy the block to your ACM hub Git (do not commit to the managed cluster repo).
- Store root token only on the hub. Optionally use ACM Policy/Placement to distribute only unseal keys back to the managed cluster as a Secret (or via External Secrets Operator); keep root token centralized.

> If you supply `bootstrap.acmPushURL`, the job will POST the encrypted blob to your hub endpoint (with optional custom CA and auth header via the `vault-bootstrap-acm` Secret).

## Unseal / Reseal

- Initial unseal is done by the hook (uses first 3 keys).
- After pod restarts, you must unseal again unless you implement auto-unseal (see below).

## Auto-unseal options (on-prem)

- Recommended (prod): Hardware HSM with pkcs11 seal (configure `server.extraEnvironmentVars` accordingly) — not provided here.
- Transit seal: Point to a separate hardened Vault (hub) — if available.
- SoftHSM2 (demo): See `values.pkcs11-softHSM.yaml` — NOT FOR PROD.

## Nuke & Rebuild

1. `argocd app delete vault -n openshift-gitops --cascade`
2. `oc delete ns vault`
3. Ensure PVCs/PVs are gone: `oc get pvc -n vault` (delete if present)
4. Re-apply the app and sync.

## Injector — example workload

Annotate a Deployment in your `demo` namespace:

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "demo"
    vault.hashicorp.com/agent-inject-secret-config.txt: "secret/data/demo/app"
```

## Monitoring

- Enable `serverTelemetry.serviceMonitor.enabled: true` and ensure your Prometheus selects it.

## Security notes

- Non-root, no extra capabilities, seccomp `RuntimeDefault`.
- `VAULT_DISABLE_MLOCK=true` is required on OpenShift restricted SCC.
- Consider readOnlyRootFilesystem=true once you validate plugins/sidecars.
- Limit SA permissions for the bootstrap job; it does not need cluster-wide RBAC.

## ACM Integration Tips

- Keep the root token only on the hub (ACM Policy/Secret in hub namespace).
- Distribute unseal keys only (no root) back to managed clusters as needed.
- Optionally adopt External Secrets Operator with your enterprise secret store to materialize only what’s needed.
