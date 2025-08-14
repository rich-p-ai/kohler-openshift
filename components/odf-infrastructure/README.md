# ODF Infrastructure Component

This component provides OpenShift Data Foundation (ODF) infrastructure nodes for storage workloads. It creates 3 dedicated infrastructure nodes with optimized resources for Ceph storage operations.

## 🎯 **Purpose**

The ODF Infrastructure component creates dedicated infrastructure nodes that:
- Host Ceph storage components (OSDs, MDS, MONs)
- Provide NooBaa object storage gateway
- Enable CSI drivers for RBD and CephFS storage
- Support high-performance storage workloads

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    ODF Infrastructure Nodes                │
├─────────────────┬─────────────────┬───────────────────────┤
│   Node 1        │   Node 2        │   Node 3              │
│   (rack0)       │   (rack1)       │   (rack2)             │
├─────────────────┼─────────────────┼───────────────────────┤
│ • 8 CPUs        │ • 8 CPUs        │ • 8 CPUs              │
│ • 64 GB RAM     │ • 64 GB RAM     │ • 64 GB RAM           │
│ • 2TB + 1TB    │ • 2TB + 1TB    │ • 2TB + 1TB          │
│   Storage       │   Storage       │   Storage             │
├─────────────────┼─────────────────┼───────────────────────┤
│ • Ceph OSD      │ • Ceph OSD      │ • Ceph OSD            │
│ • Ceph MDS      │ • Ceph MDS      │ • Ceph MON            │
│ • NooBaa        │ • NooBaa        │ • CSI Drivers         │
└─────────────────┴─────────────────┴───────────────────────┘
```

## 📋 **Prerequisites**

### 1. Cluster Requirements
- ✅ OpenShift 4.x cluster with Machine API enabled
- ✅ vSphere platform with proper credentials
- ✅ RHCOS template available in vSphere
- ✅ Sufficient vSphere resources (CPU, Memory, Storage)

### 2. Required Secrets
- `vsphere-cloud-credentials` - vSphere authentication
- `worker-user-data` - RHCOS ignition configuration

### 3. Network Requirements
- VLAN225 network access
- DHCP enabled for node provisioning
- Proper firewall rules for OpenShift communication

## 🚀 **Deployment**

### Via ArgoCD (Recommended)

This component is designed to be deployed by ArgoCD as part of the cluster configuration:

```yaml
# In your cluster values.yaml
odf-infrastructure:
  enabled: true
  labels:
    component: infrastructure
    phase: platform
  source:
    path: components/odf-infrastructure
  destination:
    namespace: openshift-machine-api
```

### Manual Deployment

```bash
# Apply the component directly
oc apply -k components/odf-infrastructure/

# Or apply individual resources
oc apply -f components/odf-infrastructure/odf-infra-machineset.yaml
oc apply -f components/odf-infrastructure/odf-infra-autoscaler.yaml
oc apply -f components/odf-infrastructure/odf-infra-config.yaml
```

## 🔧 **Configuration**

### Resource Specifications

**Compute Resources**:
- **CPU**: 8 cores (2 cores per socket)
- **Memory**: 64 GB
- **OS Disk**: 250 GB
- **Data Disk 1**: 2 TB (for ODF storage)
- **Data Disk 2**: 1 TB (additional storage)

**Network Configuration**:
- **Network**: VLAN225
- **DHCP**: Enabled
- **IP Assignment**: Automatic via DHCP

**vSphere Configuration**:
- **Datacenter**: VxRail-Datacenter
- **Cluster**: VXRail-LinuxProd
- **Datastore**: VxRail-Virtual-SAN-Datastore
- **Resource Pool**: /VxRail-Datacenter/host/VXRail-LinuxProd/Resources

### Autoscaling

**Autoscaler**: `${CLUSTER_NAME}-odf-infra-autoscaler`
- **Minimum Replicas**: 3 (required for ODF)
- **Maximum Replicas**: 6 (for future expansion)
- **Scaling Triggers**: CPU/Memory utilization > 80%

## 📊 **Monitoring and Verification**

### Health Checks

```bash
# Check MachineSet health
oc get machineset ${CLUSTER_NAME}-odf-infra -n openshift-machine-api -o yaml | grep -A 10 status

# Verify node readiness
oc get nodes -l node-role.kubernetes.io/infra= -o wide

# Check resource utilization
oc adm top nodes -l node-role.kubernetes.io/infra=
```

### ODF Readiness

```bash
# Verify ODF can schedule on infra nodes
oc get pods -n openshift-storage -o wide | grep -E "(osd|mds|mon|noobaa)"

# Check storage class availability
oc get storageclass | grep -E "(ocs|ceph|noobaa)"

# Verify Ceph cluster health
oc get cephcluster -n openshift-storage -o yaml | grep -A 5 status
```

## 🚨 **Troubleshooting**

### Common Issues

#### 1. Nodes Not Joining Cluster

**Symptoms**: Machines created but nodes not visible in cluster

**Diagnosis**:
```bash
# Check machine status
oc get machines -l machine.openshift.io/cluster-api-machineset=${CLUSTER_NAME}-odf-infra

# Check machine events
oc describe machine <machine-name> -n openshift-machine-api

# Verify vSphere credentials
oc get secret vsphere-cloud-credentials -n openshift-machine-api -o yaml
```

**Solutions**:
- Verify vSphere credentials are correct
- Check network connectivity (VLAN225)
- Ensure RHCOS template is accessible
- Verify resource availability in vSphere

#### 2. ODF Pods Not Scheduling

**Symptoms**: ODF pods stuck in Pending state

**Diagnosis**:
```bash
# Check pod events
oc describe pod <pod-name> -n openshift-storage

# Verify node selectors
oc get nodes -l node-role.kubernetes.io/infra= --show-labels

# Check taints
oc get nodes -l node-role.kubernetes.io/infra= -o yaml | grep -A 5 taints
```

**Solutions**:
- Ensure proper node labels are applied
- Verify taints are correctly configured
- Check resource availability on nodes

## 🔄 **Scaling Operations**

### Scale Up

```bash
# Increase replicas
oc scale machineset ${CLUSTER_NAME}-odf-infra --replicas=4 -n openshift-machine-api

# Or update the MachineSet directly
oc patch machineset ${CLUSTER_NAME}-odf-infra -n openshift-machine-api -p '{"spec":{"replicas":4}}'
```

### Scale Down

```bash
# Decrease replicas (minimum 3 for ODF)
oc scale machineset ${CLUSTER_NAME}-odf-infra --replicas=3 -n openshift-machine-api
```

## 📁 **File Structure**

```
components/odf-infrastructure/
├── kustomization.yaml                    # Main kustomization file
├── odf-infra-machineset.yaml            # MachineSet for ODF nodes
├── odf-infra-autoscaler.yaml            # Autoscaler configuration
├── odf-infra-config.yaml                # ODF-specific configuration
└── README.md                             # This documentation
```

## 🚀 **Next Steps**

After successful deployment of ODF infrastructure nodes:

1. **Deploy ODF Operator** (Sync Wave 5)
2. **Configure ODF Storage Cluster** (Sync Wave 15)
3. **Verify Storage Classes** are available
4. **Test PVC Creation** with new storage classes
5. **Deploy Vault** using ODF storage (Sync Wave 20+)

## 📚 **Additional Resources**

- [OpenShift Data Foundation Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation)
- [Machine API Documentation](https://docs.openshift.com/container-platform/4.18/machine_management/index.html)
- [vSphere Provider Documentation](https://docs.openshift.com/container-platform/4.18/machine_management/creating_machinesets/creating-machineset-vsphere.html)
- [Ceph Documentation](https://docs.ceph.com/en/latest/)

---

**Note**: This component uses `${CLUSTER_NAME}` variables that will be automatically populated by ArgoCD based on the target cluster configuration.
