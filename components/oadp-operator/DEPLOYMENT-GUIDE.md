# OADP GitOps Deployment Guide

This guide provides step-by-step instructions for deploying OADP (OpenShift API for Data Protection) via GitOps on the OCP-PRD cluster.

## Prerequisites

1. **Cluster Access**: Ensure you have cluster-admin access to OCP-PRD
2. **ArgoCD**: Verify ArgoCD is deployed and operational
3. **S3 Storage**: Confirm S3 storage is available and accessible
4. **GitOps Repository**: Access to the kohler-openshift GitOps repository

## Deployment Steps

### Step 1: Verify Prerequisites

```bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Verify ArgoCD is running
oc get pods -n openshift-gitops

# Check S3 storage endpoint accessibility
curl -k https://s3-openshift-storage.apps.ocp-prd.kohlerco.com
```

### Step 2: Prepare Cloud Credentials

Before deploying, ensure you have the S3 access credentials ready. These should be configured as:

```yaml
# Example cloud-credentials secret content
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: openshift-adp
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id=YOUR_ACCESS_KEY
    aws_secret_access_key=YOUR_SECRET_KEY
```

### Step 3: Deploy OADP Components via ArgoCD

#### Option A: Deploy All Components Together

Create an ArgoCD Application of Applications pattern:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oadp-deployment
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/kohler-openshift
    targetRevision: HEAD
    path: components/oadp-apps
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-gitops
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### Option B: Deploy Components Individually

Deploy each component separately with proper ordering:

1. **OADP Operator (Sync Wave 5)**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oadp-operator
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/kohler-openshift
    targetRevision: HEAD
    path: components/oadp-operator
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-adp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

2. **OADP Configuration (Sync Wave 15)**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oadp-configuration
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: "15"
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/kohler-openshift
    targetRevision: HEAD
    path: components/oadp-configuration
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-adp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

3. **OADP Scheduled Backups (Sync Wave 25)**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oadp-scheduled-backups
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: "25"
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/kohler-openshift
    targetRevision: HEAD
    path: components/oadp-scheduled-backups
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-adp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Step 4: Monitor Deployment Progress

1. **Watch ArgoCD Applications**
```bash
# Monitor all OADP applications
oc get applications -n openshift-gitops | grep oadp

# Watch application sync status
watch 'oc get applications -n openshift-gitops -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status | grep oadp'
```

2. **Monitor Component Installation**
```bash
# Run the verification script
cd components/oadp-operator/scripts
./verify-gitops-deployment.sh
```

3. **Check Individual Components**
```bash
# OADP Operator
oc get csv -n openshift-adp
oc get subscription -n openshift-adp

# OADP Configuration
oc get dpa -n openshift-adp
oc get backupstoragelocations -n openshift-adp

# Scheduled Backups
oc get schedule -n openshift-adp
```

### Step 5: Validate OADP Installation

#### 5.1 Verify Operator Status
```bash
# Check ClusterServiceVersion
oc get csv -n openshift-adp -o wide

# Verify Velero deployment
oc get deployment velero -n openshift-adp
oc get pods -n openshift-adp
```

#### 5.2 Test Backup Storage Connectivity
```bash
# Check backup storage location status
oc get backupstoragelocations -n openshift-adp -o wide

# Describe BSL for detailed status
oc describe backupstoragelocations default -n openshift-adp
```

#### 5.3 Test Manual Backup
```bash
# Create a test backup
oc create -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: test-backup-$(date +%Y%m%d-%H%M%S)
  namespace: openshift-adp
spec:
  includedNamespaces:
  - default
  storageLocation: default
  ttl: 72h0m0s
EOF

# Monitor backup progress
oc get backup -n openshift-adp
oc describe backup test-backup-* -n openshift-adp
```

## Troubleshooting Common Issues

### Issue 1: Operator Installation Fails

**Symptoms**: CSV shows "Failed" or "InstallCheckFailed"

**Resolution**:
```bash
# Check operator logs
oc get csv -n openshift-adp
oc describe csv <csv-name> -n openshift-adp

# Check subscription status
oc get subscription -n openshift-adp -o yaml
```

### Issue 2: DataProtectionApplication Not Ready

**Symptoms**: DPA shows "Phase: FailedValidation" or similar

**Resolution**:
```bash
# Check DPA configuration
oc describe dpa ocp-prd-velero-config -n openshift-adp

# Verify cloud credentials
oc get secret cloud-credentials -n openshift-adp
oc describe secret cloud-credentials -n openshift-adp
```

### Issue 3: Backup Storage Location Unavailable

**Symptoms**: BSL shows "Unavailable" status

**Resolution**:
```bash
# Check BSL details
oc describe backupstoragelocations default -n openshift-adp

# Test S3 connectivity
oc debug node/<any-node> -- chroot /host curl -k https://s3-openshift-storage.apps.ocp-prd.kohlerco.com

# Check Velero logs
oc logs deployment/velero -n openshift-adp
```

### Issue 4: Scheduled Backups Not Running

**Symptoms**: No backups created by schedules

**Resolution**:
```bash
# Check schedule configuration
oc get schedule -n openshift-adp -o yaml

# Verify schedule controller logs
oc logs deployment/velero -n openshift-adp | grep schedule

# Check if schedules are enabled
oc describe dpa ocp-prd-velero-config -n openshift-adp
```

## Post-Deployment Tasks

### 1. Configure Monitoring and Alerting

Set up monitoring for:
- Backup completion status
- Storage usage
- Failed backup alerts
- Operator health

### 2. Establish Backup Testing Procedures

Create regular procedures to:
- Test backup creation
- Validate backup integrity
- Practice restore operations
- Verify retention policies

### 3. Document Recovery Procedures

Create documentation for:
- Disaster recovery scenarios
- Application-specific restore procedures
- Cross-cluster backup scenarios
- Emergency access procedures

### 4. Schedule Regular Maintenance

Plan for:
- Monthly backup validation
- Quarterly restore testing
- Annual disaster recovery drills
- Capacity planning reviews

## Security Considerations

1. **Access Control**
   - Limit RBAC permissions for backup operations
   - Secure cloud credentials storage
   - Regular credential rotation

2. **Data Protection**
   - Verify encryption in transit and at rest
   - Implement backup data lifecycle policies
   - Monitor access logs

3. **Compliance**
   - Document retention policies
   - Ensure compliance with data regulations
   - Regular security audits

## Useful Commands Reference

```bash
# Quick status check
cd components/oadp-operator/scripts && ./verify-gitops-deployment.sh

# Monitor backups
cd components/oadp-operator/scripts && ./check-backup-status.sh

# Emergency backup
oc create backup emergency-backup-$(date +%Y%m%d-%H%M%S) --include-namespaces=<namespace> -n openshift-adp

# List all backups
oc get backup -n openshift-adp --sort-by=.metadata.creationTimestamp

# Check Velero server status
oc get deployment velero -n openshift-adp

# View all OADP resources
oc get all -n openshift-adp
```
