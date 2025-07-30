# ODF (OpenShift Data Foundation) GitOps Components

This directory contains the ODF (OpenShift Data Foundation) GitOps components for deploying software-defined storage infrastructure on OpenShift clusters.

## Component Structure

The ODF installation is split into two GitOps components following the established sync wave pattern:

### 1. ODF Operator Component (Sync Wave 5)
**Location**: `components/odf-operator/`

Installs the ODF operator:
- Namespace creation (`openshift-storage`)
- OperatorGroup configuration for the openshift-storage namespace
- Subscription to Red Hat ODF operator from redhat-operators catalog

### 2. ODF Configuration Component (Sync Wave 15)
**Location**: `components/odf-configuration/`

Configures the ODF storage cluster:
- StorageSystem resource definition
- StorageCluster with optimized resource allocation
- Configured for AWS GP3 storage with 2Ti per OSD
- Resource limits and requests for all components

## Storage Configuration

### StorageCluster Specifications
- **Storage Class**: `gp3-csi` (AWS GP3 volumes)
- **Storage Size**: 2Ti per OSD device
- **Replica Count**: 3 (for high availability)
- **Device Sets**: 1 device set with 3 replicas

### Resource Allocation
- **MDS (Metadata Server)**: 1-3 CPU, 8Gi memory
- **MGR (Manager)**: 500m-1 CPU, 3Gi memory  
- **MON (Monitor)**: 500m-1 CPU, 2Gi memory
- **OSD (Object Storage Daemon)**: 1-2 CPU, 5Gi memory
- **NooBaa Core**: 500m-1 CPU, 4Gi memory
- **NooBaa DB**: 500m-1 CPU, 4Gi memory

## Features Enabled

✅ **Flexible Scaling**: Allows dynamic scaling of storage resources  
✅ **Encryption**: Configured with KMS support for data encryption  
✅ **Multi Cloud Gateway**: NooBaa provides S3-compatible object storage  
✅ **Block and File Storage**: Ceph RBD and CephFS support  
✅ **Monitoring**: Integrated with OpenShift monitoring stack  

## Deployment via ArgoCD

Components are deployed using ArgoCD with proper sync wave ordering:

1. **Wave 5**: ODF operator installation
2. **Wave 15**: Storage cluster configuration (after operator is ready)

## Verification Commands

### Check Operator Status
```bash
# Check operator installation
oc get csv -n openshift-storage | grep odf

# Check operator pods
oc get pods -n openshift-storage | grep -E "(odf|ocs|noobaa|rook)"
```

### Check Storage Cluster Status
```bash
# Check StorageCluster status
oc get storagecluster -n openshift-storage

# Check StorageSystem status  
oc get storagesystem -n openshift-storage

# Check Ceph cluster health
oc get cephcluster -n openshift-storage

# Check all ODF resources
oc get all -n openshift-storage
```

### Check Storage Classes
```bash
# List ODF-provided storage classes
oc get storageclass | grep -E "(ocs|ceph|noobaa)"

# Common storage classes created:
# - ocs-storagecluster-ceph-rbd (Block storage)
# - ocs-storagecluster-cephfs (File storage)  
# - openshift-storage.noobaa.io (Object storage)
```

## Storage Classes Provided

After successful deployment, ODF provides these storage classes:

### Block Storage
- **ocs-storagecluster-ceph-rbd**: High-performance block storage for databases and applications
- **ocs-storagecluster-ceph-rbd-thick**: Thick provisioned block storage

### File Storage  
- **ocs-storagecluster-cephfs**: Shared filesystem storage for applications requiring ReadWriteMany

### Object Storage
- **openshift-storage.noobaa.io**: S3-compatible object storage bucket class

## Common Use Cases

### Database Storage
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: ocs-storagecluster-ceph-rbd
```

### Shared Application Storage
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-app-storage
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: ocs-storagecluster-cephfs
```

### Object Storage Bucket
```yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: app-backup-bucket
spec:
  generateBucketName: app-backup
  storageClassName: openshift-storage.noobaa.io
```

## Monitoring and Health

### Ceph Dashboard Access
```bash
# Get Ceph dashboard route (if exposed)
oc get route ceph-dashboard -n openshift-storage

# Get dashboard admin password
oc get secret rook-ceph-dashboard-password -n openshift-storage -o jsonpath="{['data']['password']}" | base64 --decode
```

### Health Checks
```bash
# Check Ceph health
oc rsh -n openshift-storage deployment/rook-ceph-tools
ceph status
ceph osd status
ceph df
```

## Troubleshooting

### Common Issues

1. **Operator Installation Fails**
   ```bash
   oc get csv -n openshift-storage
   oc describe csv <csv-name> -n openshift-storage
   ```

2. **StorageCluster Not Ready**
   ```bash
   oc describe storagecluster ocs-storagecluster -n openshift-storage
   oc get events -n openshift-storage --sort-by='.lastTimestamp'
   ```

3. **Pod Failures**
   ```bash
   oc get pods -n openshift-storage | grep -v Running
   oc logs <pod-name> -n openshift-storage
   ```

### Resource Requirements

Minimum cluster requirements:
- **Nodes**: 3 worker nodes (for replica placement)
- **CPU**: 8 cores per node minimum
- **Memory**: 16Gi per node minimum  
- **Storage**: Available storage class for PVC creation

## Security Considerations

- All data is encrypted at rest when encryption is enabled
- RBAC policies restrict access to storage resources
- Network policies can be applied for additional security
- Secrets are managed through OpenShift's secret management

## Related Documentation

- [ODF Official Documentation](https://docs.openshift.com/container-platform/latest/storage/persistent_storage/persistent-storage-ocs.html)
- [Ceph Documentation](https://docs.ceph.com/)
- [NooBaa Documentation](https://www.noobaa.io/)
