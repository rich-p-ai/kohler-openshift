# OpenShift Data Foundation (ODF) Installation Guide

This guide explains how to deploy ODF on OpenShift clusters using the configurations in this git repository.

## Overview

This ODF installation provides:
- **Ceph Storage Cluster** on dedicated infrastructure nodes
- **Cost Optimization** by using `infra` role nodes (not counted against subscription)
- **Multiple Storage Classes** for different workload types
- **High Availability** with 3-node replication
- **vSphere Integration** for storage provisioning

## Prerequisites

### 1. Infrastructure Nodes
- **3 dedicated nodes** with `infra` role (not `worker`)
- **Minimum specs per node**:
  - 8 CPUs
  - 64GB RAM
  - 250GB OS disk
  - 2TB additional storage disk
  - 1TB additional storage disk
- **Network**: Dedicated storage network (VLAN225 recommended)

### 2. vSphere Configuration
- **vSphere credentials** configured in `openshift-machine-api` namespace
- **Datastore**: Sufficient space for OSD disks
- **Network**: Storage network accessible

### 3. OpenShift Version
- **OpenShift 4.18+** (tested with 4.18.22)
- **ODF Operator 4.18** channel

## Installation Steps

### Step 1: Deploy ODF Operator

```bash
# Deploy the ODF operator components
oc kustomize kohler-openshift/components/odf-operator | oc apply -f -
```

**What this creates:**
- `openshift-storage` namespace
- ODF operator subscription
- Required operator groups and permissions

### Step 2: Deploy Infrastructure Nodes

```bash
# Deploy ODF infrastructure nodes
oc kustomize kohler-openshift/components/odf-infrastructure | oc apply -f -
```

**What this creates:**
- MachineSet for ODF infra nodes
- Machine autoscaler
- Machine config pool
- Node labels and taints

### Step 3: Configure Node Roles and Taints

**Important**: Ensure nodes are configured as `infra` role to avoid subscription counting.

```bash
# Check node roles (should show 'infra', not 'worker')
oc get nodes | grep odf-infra

# If nodes show as 'worker', fix them:
oc label nodes <node-name> node-role.kubernetes.io/worker-
oc label nodes <node-name> node-role.kubernetes.io/infra=""

# Apply storage taints
oc adm taint nodes <node-name> node.ocs.openshift.io/storage=true:NoSchedule
```

### Step 4: Deploy ODF Storage Cluster

```bash
# Deploy the ODF storage cluster
oc kustomize kohler-openshift/components/odf-configuration | oc apply -f -
```

**What this creates:**
- Storage cluster configuration
- Ceph cluster initialization
- Storage classes (after cluster is ready)

## Configuration Details

### Node Configuration

```yaml
# Node labels required
node-role.kubernetes.io/infra: ""
cluster.ocs.openshift.io/openshift-storage: ""

# Node taints applied
node-role.kubernetes.io/infra=:NoSchedule
node.ocs.openshift.io/storage=true:NoSchedule
```

### Storage Device Sets

```yaml
storageDeviceSets:
- name: ocs-deviceset
  count: 3  # One per infra node
  replica: 3
  dataPVCTemplate:
    spec:
      storageClassName: thin-csi  # vSphere storage
      storage: 2Ti  # 2TB disk per node
```

### Storage Classes Created

1. **`ocs-storagecluster-ceph-rbd`** (default)
   - Block storage for databases
   - Immediate binding
   - Volume expansion enabled

2. **`ocs-storagecluster-cephfs`**
   - File storage for applications
   - Immediate binding
   - Volume expansion enabled

3. **`ocs-storagecluster-ceph-rgw`**
   - Object storage buckets
   - S3-compatible API

4. **`openshift-storage.noobaa.io`**
   - Multi-cloud gateway
   - S3-compatible object storage

5. **`slow`**
   - Secondary RBD storage class
   - For less critical workloads

## Verification

### 1. Check Operator Status

```bash
# Verify ODF operator is running
oc get subscription -n openshift-storage
oc get csv -n openshift-storage | grep odf
```

### 2. Check Infrastructure Nodes

```bash
# Verify infra nodes are ready
oc get nodes -l node-role.kubernetes.io/infra=
oc get nodes -l cluster.ocs.openshift.io/openshift-storage=

# Check taints
oc get nodes -o custom-columns="NAME:.metadata.name,TAINTS:.spec.taints" | grep odf-infra
```

### 3. Check Storage Cluster

```bash
# Verify storage cluster status
oc get storagecluster -n openshift-storage
oc get storagesystem -n openshift-storage

# Check Ceph status
oc get cephcluster -n openshift-storage
oc get cephblockpool -n openshift-storage
```

### 4. Check Storage Classes

```bash
# Verify storage classes are created
oc get storageclass | grep ocs
```

### 5. Test Storage Provisioning

```bash
# Create a test PVC
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ocs-storagecluster-ceph-rbd
EOF

# Check PVC status
oc get pvc test-pvc
```

## Troubleshooting

### Common Issues

#### 1. Nodes Not Joining Cluster
```bash
# Check machine status
oc get machines -n openshift-machine-api | grep odf-infra

# Check machine events
oc describe machine <machine-name> -n openshift-machine-api
```

#### 2. ODF Pods Not Scheduling
```bash
# Check node taints and tolerations
oc get nodes -o custom-columns="NAME:.metadata.name,TAINTS:.spec.taints" | grep odf-infra

# Verify node labels
oc get nodes --show-labels | grep odf-infra
```

#### 3. Storage Not Provisioning
```bash
# Check Ceph cluster health
oc get cephcluster -n openshift-storage -o yaml

# Check OSD status
oc get pods -n openshift-storage | grep osd
```

#### 4. Performance Issues
```bash
# Check node resource usage
oc top nodes | grep odf-infra

# Check Ceph metrics
oc get pods -n openshift-storage | grep mgr
```

## Cost Optimization

### Why Infra Nodes?

- **Subscription Exemption**: `infra` role nodes don't count against OpenShift core limits
- **Storage Dedicated**: These nodes are dedicated to storage infrastructure
- **Workload Protection**: Regular workloads cannot schedule on these nodes

### Resource Allocation

- **3 nodes × 8 cores = 24 cores exempt from subscription**
- **Storage workloads only** with proper tolerations
- **No application workloads** can use these cores

## Scaling

### Horizontal Scaling

```bash
# Scale up infrastructure nodes
oc scale machineset <machineset-name> -n openshift-machine-api --replicas=6

# Update storage cluster for more nodes
oc patch storagecluster ocs-storagecluster -n openshift-storage --type='merge' -p='{"spec":{"storageDeviceSets":[{"name":"ocs-deviceset","count":6}]}}'
```

### Vertical Scaling

- **CPU**: Increase `numCPUs` in MachineSet
- **Memory**: Increase `memoryMiB` in MachineSet
- **Storage**: Add more disks through vSphere

## Backup and Recovery

### Backup Configuration

The storage cluster includes backup configuration:
- **S3 backup location** configured
- **Weekly key rotation** enabled
- **Graceful uninstall** mode

### Disaster Recovery

```bash
# Check DR status
oc get storagecluster -n openshift-storage -o jsonpath='{.status.phase}'

# Backup storage cluster configuration
oc get storagecluster ocs-storagecluster -n openshift-storage -o yaml > backup-storagecluster.yaml
```

## Monitoring

### Built-in Monitoring

- **Prometheus**: Enabled with 7-day retention
- **Grafana**: Dashboards enabled
- **Ceph metrics**: Available through Ceph manager

### Custom Monitoring

```bash
# Check monitoring pods
oc get pods -n openshift-storage | grep prometheus
oc get pods -n openshift-storage | grep grafana
```

## Security

### Encryption

- **At-rest encryption**: Enabled by default
- **In-transit encryption**: Enabled for Ceph connections
- **Key rotation**: Weekly schedule

### Network Security

- **Storage network isolation**: VLAN225
- **Connection encryption**: Enabled
- **Compression**: Aggressive mode

## Maintenance

### Updates

```bash
# Check for ODF updates
oc get subscription -n openshift-storage -o yaml

# Update ODF operator
oc patch subscription odf-operator -n openshift-storage --type='merge' -p='{"spec":{"channel":"stable-4.18"}}'
```

### Health Checks

```bash
# Daily health check script
oc get storagecluster -n openshift-storage
oc get cephcluster -n openshift-storage
oc get nodes -l node-role.kubernetes.io/infra=
```

## Support

### Documentation

- [ODF Official Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation)
- [Ceph Documentation](https://docs.ceph.com/)
- [OpenShift Storage](https://docs.openshift.com/container-platform/latest/storage/)

### Troubleshooting Resources

- ODF logs: `oc logs -n openshift-storage`
- Ceph logs: `oc logs -n openshift-storage -l app=rook-ceph`
- Node logs: `oc debug node/<node-name>`

---

**Note**: This configuration has been tested and proven to work on OpenShift 4.18 clusters with vSphere infrastructure. Adjust resource requirements and network configurations based on your specific environment.
