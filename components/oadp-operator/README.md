# OADP GitOps Components for OCP-PRD

This directory contains the OADP (OpenShift API for Data Protection) GitOps components for the OCP-PRD cluster. OADP provides backup and restore capabilities using Velero as the underlying technology.

## Component Structure

The OADP installation is split into three GitOps components following the established sync wave pattern:

### 1. OADP Operator Component (Sync Wave 5)
**Location**: `components/oadp-operator/`

Installs the OADP operator itself:
- Namespace creation (`openshift-adp`)
- OperatorGroup configuration
- Subscription to Red Hat OADP operator
- Utility scripts for monitoring and verification

### 2. OADP Configuration Component (Sync Wave 15)
**Location**: `components/oadp-configuration/`

Configures the OADP operator:
- Cloud credentials for S3 storage access
- DataProtectionApplication with S3 storage configuration
- Backup storage location setup
- Volume snapshot location configuration

### 3. OADP Scheduled Backups Component (Sync Wave 25)
**Location**: `components/oadp-scheduled-backups/`

Sets up automated backup schedules:
- Daily backups (retained for 7 days)
- Weekly backups (retained for 4 weeks)  
- Monthly backups (retained for 12 months)

## Storage Backend

Backups are stored on the S3-compatible storage in the OCP-HOST cluster:
- **Endpoint**: `s3-openshift-storage.apps.ocp-prd.kohlerco.com`
- **Bucket**: `velero-backup-b8287a8a-e806-4217-afc7-848ce1accf5f`
- **Access**: Uses cloud credentials stored in `openshift-adp` namespace

## Deployment via ArgoCD

All components are deployed using ArgoCD with proper sync wave ordering:

1. **Wave 5**: Operator installation
2. **Wave 15**: Operator configuration (after operator is ready)
3. **Wave 25**: Scheduled backups (after configuration is complete)

## Verification and Monitoring

### Automated Verification
Use the comprehensive verification script:
```bash
cd components/oadp-operator/scripts
./verify-gitops-deployment.sh
```

### Manual Verification
```bash
# Check operator status
oc get csv -n openshift-adp

# Check DataProtectionApplication
oc get dpa -n openshift-adp

# Check backup storage locations
oc get backupstoragelocations -n openshift-adp

# Check scheduled backups
oc get schedule -n openshift-adp

# Monitor backup status
cd components/oadp-operator/scripts
./check-backup-status.sh
```

## Backup and Restore Operations

### Manual Backup Examples
```bash
# Backup a specific namespace
oc create -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: my-app-backup
  namespace: openshift-adp
spec:
  includedNamespaces:
  - my-app-namespace
  storageLocation: default
  volumeSnapshotLocations:
  - default
EOF

# Backup specific resources
oc create -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: configmaps-backup
  namespace: openshift-adp
spec:
  includedResources:
  - configmaps
  - secrets
  storageLocation: default
EOF
```

### Restore Operations
```bash
# Restore from backup
oc create -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: my-app-restore
  namespace: openshift-adp
spec:
  backupName: my-app-backup
  excludedResources:
  - nodes
  - events
  - events.events.k8s.io
  - backups.velero.io
  - restores.velero.io
  - resticrepositories.velero.io
EOF
```

## Scheduled Backups

Three automatic backup schedules are configured:

### Daily Backups
- **Schedule**: `0 2 * * *` (2:00 AM daily)
- **Retention**: 7 days
- **Scope**: All namespaces (excluding system namespaces)

### Weekly Backups  
- **Schedule**: `0 3 * * 0` (3:00 AM every Sunday)
- **Retention**: 4 weeks
- **Scope**: All namespaces (excluding system namespaces)

### Monthly Backups
- **Schedule**: `0 4 1 * *` (4:00 AM on the 1st of each month)  
- **Retention**: 12 months
- **Scope**: All namespaces (excluding system namespaces)

## Monitoring and Alerts

### Backup Status Monitoring
```bash
# Check all backup statuses
cd components/oadp-operator/scripts
./check-backup-status.sh

# Check specific backup
oc describe backup <backup-name> -n openshift-adp

# View backup logs
oc logs -n openshift-adp deployment/velero
```

### Common Issues and Troubleshooting

1. **Backup Storage Location Not Available**
   ```bash
   oc get backupstoragelocations -n openshift-adp
   oc describe backupstoragelocations default -n openshift-adp
   ```

2. **Cloud Credentials Issues**
   ```bash
   oc get secret cloud-credentials -n openshift-adp -o yaml
   ```

3. **Velero Pod Not Running**
   ```bash
   oc get pods -n openshift-adp
   oc logs -n openshift-adp deployment/velero
   ```

## Security Considerations

- Cloud credentials are stored as Kubernetes secrets in the `openshift-adp` namespace
- RBAC policies restrict access to backup operations
- Backup data is encrypted in transit and at rest
- S3 storage access is limited to the OADP service account

## Maintenance

### Regular Tasks
1. Monitor backup completion status
2. Verify backup storage capacity
3. Test restore procedures periodically
4. Review and update retention policies as needed

### Upgrading OADP
The operator will be automatically updated through the subscription channel. Monitor the CSV status after updates:
```bash
oc get csv -n openshift-adp
```

## Related Documentation

- [OADP Official Documentation](https://docs.openshift.com/container-platform/latest/backup_and_restore/application_backup_and_restore/oadp-intro.html)
- [Velero Documentation](https://velero.io/docs/)
- [OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
