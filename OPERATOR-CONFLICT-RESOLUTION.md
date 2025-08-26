# Operator Conflict Resolution

## Problem Summary

The cluster experienced operator installation failures due to multiple OperatorGroups existing in the same namespace:

- **OADP operator** should deploy to `openshift-adp` namespace
- **MTC operator** should deploy to `openshift-migration` namespace  
- **Conflict occurred** when both operators tried to install in `openshift-migration` namespace

## Root Cause

1. Manual MTC operator installation created resources in `openshift-migration` namespace
2. OADP operator (managed by ArgoCD) also tried to install in `openshift-migration` namespace
3. OLM (Operator Lifecycle Manager) cannot choose between multiple OperatorGroups
4. CSV installations failed with error: "multiple operatorgroups, can't pick one automatically"

## Resolution Applied

### 1. Repository Configuration Updates

**OADP Operator** (`components/oadp-operator/`):
- ✅ Properly configured to deploy to `openshift-adp` namespace
- ✅ Updated to use `stable-1.4` channel (latest)
- ✅ Added proper sync wave annotations (`sync-wave: "5"`)

**MTC Operator** (`components/mtc-operator/`):
- ✅ Properly configured to deploy to `openshift-migration` namespace
- ✅ Added sync wave annotations for proper sequencing
- ✅ Fixed ArgoCD application repository URL
- ✅ Added namespace creation with sync wave `"1"`

### 2. Namespace Separation

| Operator | Namespace | Purpose |
|----------|-----------|---------|
| OADP | `openshift-adp` | Backup and restore operations |
| MTC | `openshift-migration` | Migration toolkit for containers |

### 3. ArgoCD Application Configuration

**OADP Applications** (managed via cluster values.yaml):
```yaml
oadp-operator:
  enabled: true
  destination:
    namespace: openshift-adp
    
oadp-configuration:
  enabled: true
  destination:
    namespace: openshift-adp
```

**MTC Application** (standalone application):
```yaml
# components/mtc-operator/argocd-application.yaml
destination:
  namespace: openshift-migration
```

## Manual Cleanup Required

The fix script (`scripts/fix-operator-conflicts.sh`) handles:

1. **Removes duplicate OperatorGroups** in `openshift-migration` namespace
2. **Cleans up OADP resources** from `openshift-migration` namespace
3. **Verifies proper operator deployment** in correct namespaces
4. **Checks ArgoCD application status**

## Verification Commands

```bash
# Check operator status
oc get csv -n openshift-adp     # OADP operator
oc get csv -n openshift-migration  # MTC operator

# Check OperatorGroups (should be only 1 per namespace)
oc get operatorgroups -n openshift-adp
oc get operatorgroups -n openshift-migration

# Check ArgoCD applications
oc get applications -n openshift-gitops | grep -E "(oadp|mtc)"

# Check subscriptions
oc get subscriptions -n openshift-adp
oc get subscriptions -n openshift-migration
```

## Prevention

To prevent future conflicts:

1. **Always use ArgoCD** for operator deployments when possible
2. **Separate namespaces** for different operators
3. **Use sync waves** to ensure proper deployment order
4. **Review cluster configuration** before manual installations

## Sync Wave Order

| Wave | Component | Purpose |
|------|-----------|---------|
| 1 | Namespaces | Create required namespaces |
| 5 | Operators | Install operators (OADP, MTC) |
| 15 | Configuration | Configure operators after installation |

## Files Modified

```
kohler-openshift/
├── components/
│   ├── oadp-operator/
│   │   ├── namespace.yaml          # Added sync-wave: "1"
│   │   └── operator.yaml           # Updated to stable-1.4 channel
│   └── mtc-operator/
│       ├── namespace.yaml          # Added sync-wave: "1"
│       ├── operator-group.yaml     # Added sync-wave: "5"
│       ├── subscription.yaml       # Added sync-wave: "5"
│       └── argocd-application.yaml # Fixed repo URL, added sync-wave
└── scripts/
    └── fix-operator-conflicts.sh   # Cleanup and verification script
```

## Next Steps

1. **Commit and push** all changes to the repository
2. **Run the fix script** to clean up existing conflicts
3. **Sync ArgoCD applications** to apply the corrected configurations
4. **Monitor deployment progress** using verification commands
5. **Test operator functionality** once deployment is complete

## Troubleshooting

If operators still fail to install:

1. Check for remaining duplicate OperatorGroups
2. Verify ArgoCD application sync status
3. Review operator logs and install plans
4. Ensure proper RBAC permissions
5. Check cluster resource availability
