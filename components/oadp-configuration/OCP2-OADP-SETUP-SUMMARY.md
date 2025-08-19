# OCP2 OADP Deployment Setup Summary

## What Has Been Configured

### 1. OADP Operator Component (`components/oadp-operator/`)
- **Updated to channel `stable-1.3`** (latest stable version)
- **ArgoCD Application**: `oadp-operator` in `operators-applications.yaml`
- **Sync Wave**: 5 (early deployment)
- **Purpose**: Installs the OADP operator and creates the `openshift-adp` namespace

### 2. OADP Configuration Component (`components/oadp-configuration/`)
- **Updated DataProtectionApplication** to be cluster-agnostic
- **Cross-cluster S3 configuration** pointing to OCP-HOST
- **ArgoCD Application**: `oadp-configuration` in `configuration-applications.yaml`
- **Sync Wave**: 15 (after operator installation)
- **Purpose**: Configures OADP with backup storage and settings

### 3. OCP2 Cluster Configuration (`clusters/ocp2/values.yaml`)
- **Enabled `oadp-operator`**: Installs OADP operator
- **Enabled `oadp-configuration`**: Configures OADP settings
- **Both components will be deployed via ArgoCD**

## Key Configuration Changes

### DataProtectionApplication Updates
```yaml
# Before (OCP-PRD specific)
metadata:
  name: ocp-prd-velero-config
spec:
  backupLocations:
  - velero:
      config:
        s3Url: https://s3.openshift-storage.svc:443  # Internal endpoint
      objectStorage:
        prefix: ocp-prd  # Hard-coded prefix

# After (Cluster-agnostic)
metadata:
  name: cluster-velero-config
spec:
  backupLocations:
  - velero:
      config:
        s3Url: https://s3-openshift-storage.apps.ocp-host.kohlerco.com  # External endpoint
      objectStorage:
        prefix: ${CLUSTER_NAME:-cluster}  # Dynamic prefix
```

### S3 Configuration
- **Endpoint**: `https://s3-openshift-storage.apps.ocp-host.kohlerco.com`
- **Bucket**: `kohler-oadp-backups-ec378362-ab9d-433a-bd1a-87af6e630eba`
- **Prefix**: `ocp2` (will be set by cluster values)
- **Force Path Style**: `true` (required for NooBaa compatibility)
- **Insecure TLS**: `true` (for cross-cluster communication)

## Deployment Process

### Phase 1: Operator Installation (Sync Wave 5)
1. ArgoCD deploys `oadp-operator` application
2. Creates `openshift-adp` namespace
3. Installs OADP operator subscription
4. Operator begins installation process

### Phase 2: Configuration Deployment (Sync Wave 15)
1. ArgoCD deploys `oadp-configuration` application
2. Creates cloud credentials secret (placeholder)
3. Creates DataProtectionApplication
4. OADP operator processes configuration

### Phase 3: Credential Setup (Manual)
1. **Copy credentials from OCP-HOST** using provided script
2. **Verify OADP deployment** status
3. **Test backup functionality**

## Files Created/Modified

### New Files
- `OCP2-DEPLOYMENT-GUIDE.md` - Detailed deployment guide
- `copy-credentials-to-ocp2.sh` - Automated credential copy script

### Modified Files
- `kohler-openshift/components/oadp-operator/operator.yaml` - Updated to stable-1.3
- `kohler-openshift/components/oadp-configuration/data-protection-application.yaml` - Made cluster-agnostic
- `kohler-openshift/clusters/ocp2/values.yaml` - Enabled OADP components

## Next Steps for Deployment

### 1. Commit and Push Changes
```bash
cd kohler-openshift
git add .
git commit -m "Enable OADP deployment on OCP2 cluster with cross-cluster S3 access"
git push origin main
```

### 2. Monitor ArgoCD Deployment
- Watch for `oadp-operator` application to become healthy
- Watch for `oadp-configuration` application to become healthy
- Monitor OADP operator installation progress

### 3. Copy Credentials
```bash
# Run the credential copy script
./kohler-openshift/components/oadp-configuration/copy-credentials-to-ocp2.sh
```

### 4. Verify Deployment
```bash
# Check OADP status
oc get csv -n openshift-adp
oc get dpa -n openshift-adp
oc get backupstoragelocation -n openshift-adp
```

## Benefits of This Approach

### 1. **GitOps Deployment**
- All configuration is version-controlled
- Automated deployment via ArgoCD
- Consistent across environments

### 2. **Cluster-Agnostic Design**
- Same configuration can be used for other clusters
- Easy to enable/disable per cluster
- Centralized S3 storage management

### 3. **Cross-Cluster Storage**
- Centralized backup storage on OCP-HOST
- No need to set up S3 on each cluster
- Consistent backup location and policies

### 4. **Maintainability**
- Single source of truth for OADP configuration
- Easy to update across all clusters
- Clear separation of concerns

## Troubleshooting Notes

### Common Issues
1. **ArgoCD Application Failures**
   - Check sync wave dependencies
   - Verify namespace creation order
   - Monitor operator installation logs

2. **Credential Issues**
   - Ensure credentials are copied from OCP-HOST
   - Verify secret exists in `openshift-adp` namespace
   - Check secret key names match configuration

3. **S3 Connection Issues**
   - Verify network connectivity to OCP-HOST
   - Check S3 external route accessibility
   - Validate bucket permissions

### Monitoring Commands
```bash
# Check ArgoCD application status
oc get application -n openshift-gitops

# Check OADP operator status
oc get csv -n openshift-adp

# Check Velero deployment
oc get deployment -n openshift-adp

# Check backup storage location
oc get backupstoragelocation -n openshift-adp

# Check Velero logs
oc logs -n openshift-adp -l app=velero
```

## Success Criteria

The OADP deployment on OCP2 will be considered successful when:
1. ✅ OADP operator is installed and running
2. ✅ DataProtectionApplication is reconciled successfully
3. ✅ BackupStorageLocation is available
4. ✅ Test backup can be created successfully
5. ✅ Backup data is stored in OCP-HOST S3 bucket

## Future Enhancements

### 1. **Multi-Cluster Support**
- Enable OADP on additional clusters
- Use same S3 bucket with cluster-specific prefixes
- Centralized backup management

### 2. **Backup Scheduling**
- Configure automated backup schedules
- Set up backup retention policies
- Implement backup monitoring and alerting

### 3. **Restore Testing**
- Regular restore testing procedures
- Disaster recovery validation
- Backup integrity verification
