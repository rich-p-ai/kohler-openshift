# ODF Emergency Recovery Guide
## Critical Ceph Monitor Quorum Issue Resolution

### 🚨 IMMEDIATE ACTION REQUIRED

**Issue Severity:** CRITICAL
**Impact:** Complete storage cluster unavailability, data access disruption
**Root Cause:** Resource profile changed from `balanced` to `lean`, causing Ceph monitor pods to fail

---

## Problem Analysis

### Current State
- **StorageCluster Phase:** Error
- **CephCluster Health:** HEALTH_ERR
- **Monitor Status:** Only 1 of 3 monitors running (monitor `d`)
- **Failed Components:**
  - Monitor pods `a` and `b` (Pending/failed to start)
  - NooBaa pods (Pending)
  - OSD pods (Pending)

### Root Cause
The resource profile was changed from `balanced` (default) to `lean`, which significantly reduced CPU and memory allocations for Ceph components:

- **Monitor memory:** Reduced from 2Gi to insufficient levels
- **Manager memory:** Reduced from 4Gi to insufficient levels
- **Result:** Monitors cannot start, preventing quorum formation

### Impact Assessment
1. **Data Unavailability:** Existing PVCs may be inaccessible
2. **No New Storage:** Cannot provision new persistent volumes
3. **Application Disruption:** Any pods using Ceph storage are affected
4. **Recovery Complexity:** Requires manual intervention to restore quorum

---

## Immediate Remediation Steps

### Option 1: Emergency Script (Recommended for immediate fix)

```bash
# 1. Connect to the cluster
oc login -u kubeadmin -p <password> --server=<api-server>

# 2. Run the emergency fix script
cd kohler-openshift/scripts
./emergency-odf-resource-profile-fix.sh
```

### Option 2: Manual Fix (If script unavailable)

```bash
# Revert resource profile to balanced
oc patch storagecluster ocs-storagecluster -n openshift-storage --type='merge' -p='
{
  "spec": {
    "resourceProfile": "balanced",
    "resources": {
      "mgr": {
        "limits": {"cpu": "2", "memory": "4Gi"},
        "requests": {"cpu": "1", "memory": "2Gi"}
      },
      "mon": {
        "limits": {"cpu": "2", "memory": "2Gi"},
        "requests": {"cpu": "1", "memory": "1Gi"}
      },
      "osd": {
        "limits": {"cpu": "2", "memory": "4Gi"},
        "requests": {"cpu": "1", "memory": "2Gi"}
      }
    }
  }
}'
```

---

## Validation Steps

After applying the fix, validate the recovery:

```bash
# Run the validation script
cd kohler-openshift/scripts
./validate-odf-cluster-health.sh

# Or manually check key components
oc get storagecluster -n openshift-storage
oc get cephcluster -n openshift-storage
oc get pods -l app=rook-ceph-mon -n openshift-storage
```

**Expected Results:**
- ✅ All 3 monitors running
- ✅ OSD pods running
- ✅ StorageCluster phase: `Ready`
- ✅ CephCluster health: `HEALTH_OK` or `HEALTH_WARN`

---

## Long-term Prevention

### 1. GitOps Configuration Fixed
The repository has been updated with:
- `storage-cluster-resource-profile-fix.yaml` - Ensures balanced resource profile
- Updated `kustomization.yaml` to include the fix
- Emergency scripts for immediate response

### 2. Monitoring Recommendations
```bash
# Monitor Ceph health continuously
oc get cephcluster -n openshift-storage -w

# Check monitor status regularly
oc get pods -l app=rook-ceph-mon -n openshift-storage

# Validate cluster health
ceph status  # Run inside toolbox pod
```

### 3. Resource Profile Guidelines
- **NEVER change resource profile without testing**
- **Always use `balanced` for production workloads**
- **`lean` profile is for development/testing only**
- **Test resource changes in non-production first**

---

## Recovery Timeline

### Immediate (0-30 minutes)
- Apply resource profile fix
- Monitor pod startup
- Validate monitor quorum

### Short-term (30-60 minutes)
- OSD pods start and join cluster
- NooBaa components recover
- Storage classes become available

### Long-term (1-4 hours)
- Full cluster reconciliation
- Data rebalancing if required
- Performance optimization

---

## Emergency Contacts

If issues persist after applying fixes:
1. Check cluster events: `oc get events -n openshift-storage --sort-by=.lastTimestamp`
2. Examine pod logs: `oc logs <pod-name> -n openshift-storage --previous`
3. Contact Red Hat support with cluster details

---

## Files Modified

### New Files Created:
- `components/odf-configuration/storage-cluster-resource-profile-fix.yaml`
- `scripts/emergency-odf-resource-profile-fix.sh`
- `scripts/validate-odf-cluster-health.sh`
- `ODF-EMERGENCY-RECOVERY-README.md`

### Files Updated:
- `components/odf-configuration/kustomization.yaml`

---

## Risk Assessment

**High Risk:** Data loss if cluster remains in failed state
**Medium Risk:** Application downtime during recovery
**Low Risk:** Temporary performance impact during rebalancing

**Recovery Confidence:** High - This is a standard resource allocation fix

---

*This recovery guide was generated by the ODF Ceph Expert inspection and resolution process.*
