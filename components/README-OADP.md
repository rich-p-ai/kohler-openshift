# OADP Components Documentation

This directory contains the OpenShift API for Data Protection (OADP) components for the Kohler OpenShift GitOps deployment.

## Components Overview

The OADP deployment is split into three components following the standard sync wave pattern:

### 1. oadp-operator (Sync Wave 1-10, default 5)
- **Purpose**: Installs the Red Hat OADP operator
- **Sync Wave**: 5 (operator installation)
- **Resources**:
  - Namespace creation for `openshift-adp`
  - OperatorGroup configuration
  - Subscription to Red Hat OADP operator

### 2. oadp-configuration (Sync Wave 10-20, default 15)
- **Purpose**: Configures the Data Protection Application and storage credentials
- **Sync Wave**: 15 (operator configuration)
- **Resources**:
  - Cloud credentials secret for S3 backup storage
  - DataProtectionApplication custom resource
  - Backup and snapshot storage location configuration

### 3. oadp-scheduled-backups (Sync Wave 20-30, default 25)
- **Purpose**: Configures automated backup schedules
- **Sync Wave**: 25 (additional configurations)
- **Resources**:
  - Daily backup schedule for critical namespaces
  - Weekly full cluster backup schedule
  - Monthly archive backup schedule

## Backup Storage Configuration

- **Storage Type**: S3-compatible storage on OCP-Host
- **Endpoint**: `s3-openshift-storage.apps.ocp-prd.kohlerco.com`
- **Bucket**: `velero-backup-b8287a8a-e806-4217-afc7-848ce1accf5f`
- **Prefix**: `ocp-prd`

## Backup Schedules

| Schedule | Frequency | Retention | Scope |
|----------|-----------|-----------|-------|
| Daily Critical | 2:00 AM daily | 30 days | Critical namespaces only |
| Weekly Full | 1:00 AM Sunday | 90 days | All namespaces (excluding system) |
| Monthly Archive | Midnight 1st of month | 1 year | Complete cluster backup |

## Features Enabled

- **CSI Snapshots**: Enabled for persistent volume snapshots
- **Restic**: Enabled for file-level backup of pod volumes
- **Node Agent**: Enabled for enhanced backup capabilities
- **OpenShift Plugin**: Enabled for OpenShift-specific resources

## Usage in ArgoCD Applications

To include OADP in your cluster deployment, reference these components in your ArgoCD Application:

```yaml
spec:
  sources:
  # Operator installation (sync wave 5)
  - repoURL: https://github.com/your-org/kohler-openshift.git
    path: components/oadp-operator
    targetRevision: main
  
  # Configuration (sync wave 15)
  - repoURL: https://github.com/your-org/kohler-openshift.git
    path: components/oadp-configuration
    targetRevision: main
  
  # Scheduled backups (sync wave 25)
  - repoURL: https://github.com/your-org/kohler-openshift.git
    path: components/oadp-scheduled-backups
    targetRevision: main
```

## Manual Backup Examples

For manual backups, see the original examples in the `oadp-installation/examples/` directory:
- `backup-example.yaml` - Single namespace backup
- `restore-example.yaml` - Restore from backup
- `cluster-backup.yaml` - Full cluster disaster recovery backup

## Monitoring

Use the monitoring script from the original installation:
```bash
./oadp-installation/scripts/check-backup-status.sh
```

## Security Notes

⚠️ **Important**: The cloud credentials contain sensitive S3 access keys. In production:
1. Use sealed secrets or external secret management
2. Rotate credentials regularly
3. Apply principle of least privilege for S3 bucket access

## Troubleshooting

Common commands for troubleshooting:
```bash
# Check operator status
oc get csv -n openshift-adp

# Check DPA status
oc get dpa -n openshift-adp

# Check backup storage location
oc get backupstoragelocations -n openshift-adp

# View Velero logs
oc logs -n openshift-adp deployment/velero
```
