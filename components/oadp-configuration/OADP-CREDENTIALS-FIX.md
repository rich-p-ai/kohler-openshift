# OADP Credentials Fix for OCP-PRD Cluster

## Problem Description

The OADP (OpenShift API for Data Protection) backup operations on the `ocp-prd` cluster are failing with the following error:

```
Fatal: create repository at s3:http://s3.openshift-storage.svc/kohler-oadp-backups-ec378362-ab9d-433a-bd1a-87af6e630eba/balance-fit/restic/tmsapplications failed: client.BucketExists: The AWS access key Id you provided does not exist in our records.
```

## Root Cause

The issue is caused by a **credential mismatch** between what OADP is trying to use and what the S3 service expects. Specifically:

1. **Wrong S3 Endpoint**: OADP was configured to use `https://s3-openshift-storage.apps.ocp-prd.kohlerco.com` (external endpoint on ocp-prd)
2. **Wrong Bucket**: OADP was configured to use bucket `velero-backup-b8287a8a-e806-4217-afc7-848ce1accf5f`
3. **Missing Credentials**: The cloud credentials secret contains placeholder values instead of real S3 credentials

## Correct Configuration

According to the DR setup documentation, the S3 storage is actually configured on the **`ocp-host`** cluster, not on `ocp-prd`. The correct configuration should be:

- **S3 Endpoint**: `https://s3.openshift-storage.svc:443` (internal service on ocp-host)
- **Bucket**: `kohler-oadp-backups-ec378362-ab9d-433a-bd1a-87af6e630eba`
- **Region**: `us-east-1`
- **Path Style**: `true`

## Solution Steps

### Step 1: Update OADP Configuration

The OADP configuration has been updated in `data-protection-application.yaml` to use the correct S3 settings:

```yaml
spec:
  backupLocations:
  - velero:
      config:
        region: us-east-1
        s3ForcePathStyle: "true"
        s3Url: https://s3.openshift-storage.svc:443
        insecureSkipTLSVerify: "true"
      objectStorage:
        bucket: kohler-oadp-backups-ec378362-ab9d-433a-bd1a-87af6e630eba
        prefix: ocp-prd
```

### Step 2: Copy Credentials from OCP-Host

The real S3 credentials exist on the `ocp-host` cluster and need to be copied to `ocp-prd`. Use the provided script:

```bash
# Make script executable
chmod +x copy-credentials-from-ocp-host.sh

# Run the script
./copy-credentials-from-ocp-host.sh
```

**Manual Alternative:**
```bash
# 1. Login to ocp-host cluster
oc login https://api.ocp-host.kohlerco.com:6443

# 2. Export the credentials
oc get secret cloud-credentials -n openshift-adp -o yaml > /tmp/credentials.yaml

# 3. Login to ocp-prd cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# 4. Apply the credentials
oc apply -f /tmp/credentials.yaml
```

### Step 3: Verify the Fix

After copying the credentials, verify the setup:

```bash
# Check that the secret exists
oc get secret cloud-credentials -n openshift-adp

# Check OADP status
oc get dpa -n openshift-adp

# Check backup storage locations
oc get backupstoragelocations -n openshift-adp

# Check Velero pods
oc get pods -n openshift-adp
```

## Why This Happened

1. **Architecture Mismatch**: The S3 storage was configured on `ocp-host` but OADP was trying to use it from `ocp-prd`
2. **Credential Isolation**: Each cluster has its own credential namespace, so credentials don't automatically sync
3. **Configuration Drift**: The OADP configuration was pointing to the wrong S3 endpoint and bucket

## Prevention

To prevent this issue in the future:

1. **Document S3 Architecture**: Clearly document which cluster hosts the S3 storage
2. **Credential Management**: Use a centralized credential management solution (Vault, External Secrets Operator)
3. **Configuration Validation**: Validate OADP configuration against the actual S3 infrastructure
4. **Monitoring**: Set up alerts for OADP backup failures

## Related Files

- `data-protection-application.yaml` - Updated OADP configuration
- `backup-storage-credentials.yaml` - Credential template (contains placeholders)
- `copy-credentials-from-ocp-host.sh` - Script to copy credentials
- `OADP-CREDENTIALS-FIX.md` - This documentation

## Support

If you continue to experience issues after following these steps:

1. Check the Velero logs: `oc logs -f deployment/velero -n openshift-adp`
2. Verify S3 connectivity from the ocp-prd cluster
3. Ensure the ocp-host S3 service is accessible from ocp-prd
4. Check network policies and firewall rules between clusters
