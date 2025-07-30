# 🚀 Quick Deployment Guide: Daily App Namespace Backups

This guide will get your daily OADP backups running quickly on ocp-prd.

## ✅ What You Get

- **Daily backups** at 3:00 AM for your app namespaces
- **30-day retention** for application data
- **Storage on ocp-host** using your existing S3 setup
- **Automatic recovery** of persistent volumes, secrets, configmaps, etc.

## 📋 Prerequisites

1. **OADP is already installed** on ocp-prd (✅ You have this)
2. **S3 storage configured** on ocp-host (✅ You have this)
3. **Access to ocp-prd cluster** as cluster admin

## 🚀 Quick Setup (5 minutes)

### Step 1: Login to ocp-prd
```bash
oc login https://api.ocp-prd.kohlerco.com:6443
```

### Step 2: Navigate to backup components
```bash
cd "c:\work\OneDrive - Kohler Co\Openshift\git\kohler-openshift\components\oadp-scheduled-backups"
```

### Step 3: Customize your namespaces
Edit `app-namespace-daily-backup.yaml` and replace the example namespaces with your actual app namespaces:

```yaml
# Line ~25-30: Replace these with your app namespaces
includedNamespaces:
- your-app-namespace-1     # Replace with actual namespace
- your-app-namespace-2     # Replace with actual namespace
- balance-fit-prd          # Keep if you want this backed up
- data-analytics           # Keep if you want this backed up
```

### Step 4: Deploy the backup schedule
```bash
# Deploy directly to cluster
oc apply -f app-namespace-daily-backup.yaml

# OR use the setup script for interactive setup
./setup-app-backup.sh
```

### Step 5: Verify deployment
```bash
# Check if the schedule was created
oc get schedule daily-app-namespace-backup -n openshift-adp

# Verify it shows your namespaces
oc describe schedule daily-app-namespace-backup -n openshift-adp
```

## 🔍 Verification

Run the verification script to ensure everything is working:
```bash
./verify-app-backup.sh
```

This will check:
- ✅ OADP operator status
- ✅ Backup storage connectivity
- ✅ Schedule configuration
- ✅ Recent backup status

## 📊 Monitor Your Backups

### Daily Monitoring
```bash
# Check backup status
oc get backup -n openshift-adp

# View latest backups
oc get backup -n openshift-adp --sort-by=.metadata.creationTimestamp
```

### Check Your Schedule
```bash
# View all scheduled backups
oc get schedule -n openshift-adp

# Check when your app backup last ran
oc get schedule daily-app-namespace-backup -n openshift-adp -o yaml
```

## 🔄 Test a Restore

When you need to restore (test this in non-production first!):

```bash
# List available backups
oc get backup -n openshift-adp

# Create a restore
oc create -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: test-restore-$(date +%Y%m%d-%H%M%S)
  namespace: openshift-adp
spec:
  backupName: <your-backup-name>
  includedNamespaces:
  - your-namespace-to-restore
EOF

# Monitor restore progress
oc get restore -n openshift-adp
```

## ⚠️ Important Notes

1. **First backup**: Will run tomorrow at 3:00 AM (or create a test backup now)
2. **Storage location**: Uses your existing ocp-host S3 storage
3. **Retention**: 30 days (720 hours) - adjust in the YAML if needed
4. **Conflicts**: Scheduled at 3:00 AM to avoid conflicts with existing backups

## 🆘 Troubleshooting

### Backup not running?
```bash
# Check Velero logs
oc logs -n openshift-adp deployment/velero

# Check schedule status
oc describe schedule daily-app-namespace-backup -n openshift-adp
```

### Storage issues?
```bash
# Check backup storage location
oc get backupstoragelocations -n openshift-adp

# Check S3 connectivity
oc describe backupstoragelocations ocp-prd-backup-location -n openshift-adp
```

## 📞 Next Steps

After deployment:
1. **Wait for first backup** (tomorrow 3:00 AM) or create a test backup
2. **Monitor backup success** daily
3. **Test restore procedure** in a safe environment
4. **Add more namespaces** as needed by editing the YAML file

---

**🎉 You're all set!** Your app namespaces will be automatically backed up daily to ocp-host storage.
