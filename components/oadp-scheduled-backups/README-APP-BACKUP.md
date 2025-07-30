# Daily App Namespace Backup Setup Guide

This guide helps you configure daily OADP backups for your application namespaces on ocp-prd, storing backups to ocp-host.

## 📋 Overview

The configuration creates:
- **Daily backups** at 3:00 AM for your app namespaces
- **30-day retention** for application backups
- **Storage on ocp-host** using existing S3 configuration
- **Application-focused backup** excluding system resources

## 🚀 Quick Setup

### Step 1: Login to ocp-prd cluster
```bash
oc login https://api.ocp-prd.kohlerco.com:6443
```

### Step 2: Navigate to the OADP components directory
```bash
cd "c:\work\OneDrive - Kohler Co\Openshift\git\kohler-openshift\components\oadp-scheduled-backups"
```

### Step 3: Run the setup script
```bash
chmod +x setup-app-backup.sh
./setup-app-backup.sh
```

### Step 4: Customize for your namespaces
Edit `app-namespace-daily-backup.yaml` and update the `includedNamespaces` section:
```yaml
includedNamespaces:
- your-app-namespace-1
- your-app-namespace-2  
- balance-fit-prd
- data-analytics
# Add your specific app namespaces here
```

### Step 5: Deploy via GitOps (Recommended)
```bash
# Commit changes to Git
git add .
git commit -m "Add daily app namespace backup configuration"
git push

# The ArgoCD application will automatically sync the changes
```

### Alternative: Direct Deployment
```bash
# Apply directly if not using GitOps
oc apply -f app-namespace-daily-backup.yaml
```

## ⚙️ Configuration Details

### Backup Schedule
- **Time**: Daily at 3:00 AM (avoids conflicts with other scheduled backups)
- **Retention**: 30 days (720 hours)
- **Storage**: ocp-host S3 (`s3-openshift-storage.apps.ocp-prd.kohlerco.com`)

### What Gets Backed Up
✅ **Included:**
- Deployments, Services, Routes
- ConfigMaps and Secrets
- PersistentVolumeClaims and data
- ServiceAccounts and RoleBindings
- Custom Resources

❌ **Excluded:**
- System namespaces (openshift-*, kube-*)
- Volatile resources (pods, events, replicasets)
- Cluster-scoped resources (focus on app namespaces)

### Storage Configuration
```yaml
storageLocation: ocp-prd-backup-location
volumeSnapshotLocations:
- ocp-prd-snapshot-location
```

## 📊 Monitoring Your Backups

### Check Backup Status
```bash
# View all backup schedules
oc get schedule -n openshift-adp

# View all backups
oc get backup -n openshift-adp

# Check your daily app backup schedule
oc describe schedule daily-app-namespace-backup -n openshift-adp
```

### Monitor Backup Progress
```bash
# Watch backups in real-time
oc get backup -n openshift-adp -w

# View detailed backup information
oc describe backup <backup-name> -n openshift-adp

# Check Velero logs
oc logs -n openshift-adp deployment/velero
```

### Verify Storage Connection
```bash
# Check backup storage location status
oc get backupstoragelocations -n openshift-adp

# Detailed storage location info
oc describe backupstoragelocations ocp-prd-backup-location -n openshift-adp
```

## 🔄 Restore Procedures

### List Available Backups
```bash
oc get backup -n openshift-adp --sort-by=.metadata.creationTimestamp
```

### Restore a Namespace
```bash
# Create restore from specific backup
oc create -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-my-app-$(date +%Y%m%d-%H%M%S)
  namespace: openshift-adp
spec:
  backupName: <backup-name>
  includedNamespaces:
  - my-app-namespace
  excludedResources:
  - nodes
  - events
  - events.events.k8s.io
  - backups.velero.io
  - restores.velero.io
  - resticrepositories.velero.io
EOF
```

### Monitor Restore Progress
```bash
# Check restore status
oc get restore -n openshift-adp

# View restore details
oc describe restore <restore-name> -n openshift-adp
```

## 🛠️ Customization Options

### Modify Backup Schedule
Edit the `schedule` field in `app-namespace-daily-backup.yaml`:
```yaml
# Examples:
schedule: "0 3 * * *"    # Daily at 3:00 AM
schedule: "0 2 * * *"    # Daily at 2:00 AM  
schedule: "0 */12 * * *" # Every 12 hours
```

### Change Retention Period
```yaml
# Examples:
ttl: 720h0m0s   # 30 days (current)
ttl: 168h0m0s   # 7 days
ttl: 2160h0m0s  # 90 days
```

### Add Application Hooks
For database-consistent backups, add hooks:
```yaml
hooks:
  resources:
  - name: database-backup-hook
    includedNamespaces:
    - my-database-namespace
    includedResources:
    - pods
    labelSelector:
      matchLabels:
        app: postgresql
    pre:
    - exec:
        command:
        - /bin/bash
        - -c
        - "pg_dump database > /tmp/backup.sql"
        container: postgresql
        timeout: 5m
    post:
    - exec:
        command:
        - /bin/bash
        - -c
        - "rm -f /tmp/backup.sql"
        container: postgresql
        timeout: 1m
```

## 🚨 Troubleshooting

### Backup Fails
1. **Check storage connectivity:**
   ```bash
   oc describe backupstoragelocations -n openshift-adp
   ```

2. **Check Velero logs:**
   ```bash
   oc logs -n openshift-adp deployment/velero
   ```

3. **Verify namespace exists:**
   ```bash
   oc get namespace <your-namespace>
   ```

### Storage Issues
1. **Check S3 credentials:**
   ```bash
   oc get secret cloud-credentials -n openshift-adp -o yaml
   ```

2. **Test storage location:**
   ```bash
   oc get backupstoragelocations -n openshift-adp -o wide
   ```

### Schedule Not Running
1. **Check schedule status:**
   ```bash
   oc describe schedule daily-app-namespace-backup -n openshift-adp
   ```

2. **Verify schedule format:**
   ```bash
   # Should be in cron format: "minute hour day month dayofweek"
   schedule: "0 3 * * *"
   ```

## 📈 Best Practices

### Security
- ✅ Use sealed secrets for S3 credentials in production
- ✅ Implement RBAC for backup access
- ✅ Regularly rotate S3 access keys
- ✅ Monitor backup access logs

### Operations
- ✅ Test restore procedures regularly
- ✅ Monitor backup success daily
- ✅ Check storage space on ocp-host
- ✅ Document restore procedures for your team
- ✅ Set up alerts for backup failures

### Performance
- ✅ Schedule backups during low-usage periods
- ✅ Use volume snapshots for large datasets
- ✅ Consider backup size vs. retention trade-offs
- ✅ Monitor backup duration trends

## 📁 File Structure

```
components/oadp-scheduled-backups/
├── scheduled-backups.yaml           # Existing scheduled backups
├── app-namespace-daily-backup.yaml  # NEW: Your app namespace backup
├── kustomization.yaml              # Updated to include new backup
├── setup-app-backup.sh             # Setup script
└── README-APP-BACKUP.md            # This documentation
```

## 🔗 Related Documentation

- [OADP Operator README](../oadp-operator/README.md)
- [OADP Configuration Guide](../oadp-configuration/README.md)
- [OADP Deployment Guide](../oadp-operator/DEPLOYMENT-GUIDE.md)
- [Velero Documentation](https://velero.io/docs/)

## 📞 Support

For issues or questions:
1. Check Velero logs: `oc logs -n openshift-adp deployment/velero`
2. Verify OADP configuration: `oc get dpa -n openshift-adp`
3. Check backup storage: `oc get backupstoragelocations -n openshift-adp`
4. Review ArgoCD sync status if using GitOps

---

**Created**: $(date)  
**Backup Schedule**: Daily at 3:00 AM  
**Storage**: ocp-host S3 storage  
**Retention**: 30 days
