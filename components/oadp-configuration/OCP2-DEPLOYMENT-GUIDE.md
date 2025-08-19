# OADP Deployment Guide for OCP2 Cluster

## Overview
This guide explains how to deploy OADP (OpenShift Application Data Protection) on the OCP2 cluster using the cross-cluster S3 storage approach. The S3 bucket is hosted on the OCP-HOST cluster and accessed externally by OCP2.

## Prerequisites
- Access to OCP2 cluster with cluster-admin privileges
- Access to OCP-HOST cluster to copy S3 credentials
- ArgoCD already deployed and configured on OCP2

## Architecture
```
OCP2 Cluster                    OCP-HOST Cluster
┌─────────────────┐            ┌─────────────────┐
│                 │            │                 │
│  OADP/Velero   │────────────▶│  S3 Service     │
│                 │            │  (NooBaa)       │
│                 │            │                 │
└─────────────────┘            └─────────────────┘
```

## Deployment Steps

### 1. Enable OADP in Cluster Values
The OCP2 cluster values.yaml has been updated to enable:
- `oadp-operator`: Installs the OADP operator
- `oadp-configuration`: Configures OADP with cross-cluster S3 access

### 2. Deploy OADP Components
The components are deployed via ArgoCD from the `kohler-openshift` repository:

- **OADP Operator** (sync-wave: 5)
  - Creates the `openshift-adp` namespace
  - Installs the OADP operator subscription
  - Uses channel `stable-1.3`

- **OADP Configuration** (sync-wave: 15)
  - Creates the cloud credentials secret
  - Configures the DataProtectionApplication
  - Sets up backup storage location pointing to OCP-HOST S3

### 3. Copy S3 Credentials from OCP-HOST
Before OADP can function, you must copy the S3 credentials:

```bash
# Login to OCP-HOST cluster
oc login -u kubeadmin -p <password> --server=https://api.ocp-host.kohlerco.com:6443

# Export the cloud credentials secret
oc get secret cloud-credentials -n openshift-adp -o yaml > cloud-credentials-ocp-host.yaml

# Login to OCP2 cluster
oc login -u kubeadmin -p FUKeF-MWGqX-H52Et-8wx5T --server=https://api.ocp2.kohlerco.com:6443

# Apply the credentials to OCP2
oc apply -f cloud-credentials-ocp-host.yaml
```

### 4. Verify OADP Deployment
Check that all OADP components are running:

```bash
# Check OADP operator status
oc get csv -n openshift-adp

# Check Velero deployment
oc get deployment -n openshift-adp

# Check DataProtectionApplication status
oc get dpa -n openshift-adp

# Check BackupStorageLocation status
oc get backupstoragelocation -n openshift-adp
```

### 5. Test Backup Functionality
Create a test backup to verify the setup:

```bash
# Create a test backup
oc create -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: test-ocp2-backup
  namespace: openshift-adp
spec:
  includedNamespaces:
  - openshift-adp
  includedResources:
  - secrets
  excludedResources:
  - pods
  - pvs
  - pvcs
  storageLocation: cluster-backup-location
  ttl: 720h0m0s
EOF
```

## Configuration Details

### S3 Configuration
- **Endpoint**: `https://s3-openshift-storage.apps.ocp-host.kohlerco.com`
- **Bucket**: `kohler-oadp-backups-ec378362-ab9d-433a-bd1a-87af6e630eba`
- **Prefix**: `ocp2` (cluster-specific)
- **Force Path Style**: `true` (required for NooBaa compatibility)
- **Insecure TLS**: `true` (for internal cluster communication)

### Backup Strategy
- **File-level backups**: Using NodeAgent with Restic
- **CSI snapshots**: Enabled for persistent volume backups
- **Cross-cluster storage**: Centralized backup storage on OCP-HOST

## Troubleshooting

### Common Issues

1. **InvalidAccessKeyId Error**
   - Verify credentials were copied correctly from OCP-HOST
   - Check that the secret exists in `openshift-adp` namespace

2. **S3 Connection Timeout**
   - Verify network connectivity between OCP2 and OCP-HOST
   - Check that the S3 external route is accessible

3. **BackupStorageLocation Not Available**
   - Check Velero logs: `oc logs -n openshift-adp -l app=velero`
   - Verify S3 bucket exists and is accessible

### Logs and Debugging
```bash
# Check Velero logs
oc logs -n openshift-adp -l app=velero

# Check NodeAgent logs
oc logs -n openshift-adp -l app=node-agent

# Check OADP operator logs
oc logs -n openshift-adp -l name=oadp-operator
```

## Next Steps
After successful deployment:
1. Configure backup schedules for critical applications
2. Set up backup retention policies
3. Test restore procedures
4. Document backup/restore procedures for the team

## References
- [OADP Documentation](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.14/html/backup_and_restore/index)
- [Velero Documentation](https://velero.io/docs/)
- [NooBaa S3 Compatibility](https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation/4.12/html-single/managing_hybrid_and_multicloud_resources/index)
