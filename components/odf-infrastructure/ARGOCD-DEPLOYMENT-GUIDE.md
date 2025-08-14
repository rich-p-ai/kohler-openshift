# ArgoCD Deployment Guide for ODF Infrastructure

This guide explains how to deploy the ODF Infrastructure component using ArgoCD, enabling automated deployment of 3 dedicated storage nodes across multiple OpenShift clusters.

## 🎯 **Overview**

The ODF Infrastructure component is designed to be deployed by ArgoCD as part of the cluster configuration. It automatically creates 3 infrastructure nodes optimized for OpenShift Data Foundation storage workloads.

## 🏗️ **Component Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    ArgoCD Application                      │
│                    (odf-infrastructure)                    │
├─────────────────────────────────────────────────────────────┤
│                    ODF Infrastructure Component            │
│                    (Sync Wave 4)                          │
├─────────────────┬─────────────────┬───────────────────────┤
│   ConfigMap     │   MachineSet    │   MachineAutoscaler   │
│  (cluster-info) │ (3 infra nodes) │   (3-6 replicas)     │
├─────────────────┼─────────────────┼───────────────────────┤
│ • Cluster Name  │ • 8 CPUs        │ • Min: 3 nodes       │
│ • Domain        │ • 64 GB RAM     │ • Max: 6 nodes       │
│ • Platform      │ • 2TB + 1TB    │ • Auto-scaling       │
│ • Network       │   Storage       │ • Health monitoring  │
└─────────────────┴─────────────────┴───────────────────────┘
```

## 📋 **Prerequisites**

### 1. ArgoCD Requirements
- ✅ ArgoCD installed and running on target cluster
- ✅ ArgoCD ApplicationSet controller enabled
- ✅ Proper RBAC permissions for Machine API operations

### 2. Cluster Requirements
- ✅ OpenShift 4.x cluster with Machine API enabled
- ✅ vSphere platform with proper credentials
- ✅ RHCOS template available in vSphere
- ✅ Sufficient vSphere resources (CPU, Memory, Storage)

### 3. Repository Access
- ✅ ArgoCD has access to the kohler-openshift repository
- ✅ Repository contains the ODF infrastructure components
- ✅ Proper authentication configured

## 🚀 **Deployment via ArgoCD**

### Step 1: Enable Component in Cluster Values

Add the ODF infrastructure component to your cluster's `values.yaml`:

```yaml
# In clusters/ocp2/values.yaml or similar
applications:
  # ... other applications ...
  
  # Phase 5: Platform Integration (Sync Wave 4-6)
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

### Step 2: Deploy via ApplicationSet

The component will be automatically deployed when you apply the root application:

```bash
# Apply the root application to trigger ODF infrastructure deployment
oc apply -f .bootstrap/6.root-application.yaml

# Or if using kustomize
oc apply -k .bootstrap/
```

### Step 3: Monitor Deployment

```bash
# Check ArgoCD application status
oc get application odf-infrastructure -n openshift-gitops

# Monitor sync status
oc get application odf-infrastructure -n openshift-gitops -o yaml | grep -A 10 "status:"
```

## 🔧 **Configuration Customization**

### Cluster-Specific Variables

The component uses `${CLUSTER_NAME}` variables that are automatically populated. To customize for different clusters:

1. **Update cluster-info.yaml**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-info
  namespace: openshift-machine-api
data:
  cluster-name: "your-cluster-name"  # Change this
  cluster-domain: "your-domain.com"  # Change this
  cluster-type: "production"
  storage-platform: "vsphere"
  storage-network: "VLAN225"
```

2. **Update vSphere paths** in the MachineSet:
```yaml
# In odf-infra-machineset.yaml
workspace:
  datacenter: "Your-Datacenter"           # Change this
  datastore: "/Your-Datacenter/datastore/Your-Datastore"  # Change this
  folder: "/Your-Datacenter/vm/Your-Folder"               # Change this
  resourcePool: "/Your-Datacenter/host/Your-Cluster/Resources"  # Change this
  server: "your-vcenter.kohlerco.com"     # Change this
```

### Resource Customization

To modify compute resources:

```yaml
# In odf-infra-machineset.yaml
providerSpec:
  value:
    # Adjust these values as needed
    numCoresPerSocket: 2
    memoryMiB: 65536      # 64 GB
    numCPUs: 8            # 8 CPUs
    diskGiB: 250          # OS disk
    disk1GiB: 2048        # Data disk 1 (2TB)
    disk2GiB: 1024        # Data disk 2 (1TB)
```

## 📊 **Monitoring and Verification**

### ArgoCD Application Status

```bash
# Check application health
oc get application odf-infrastructure -n openshift-gitops -o jsonpath='{.status.health.status}'

# Check sync status
oc get application odf-infrastructure -n openshift-gitops -o jsonpath='{.status.sync.status}'

# View sync history
oc get application odf-infrastructure -n openshift-gitops -o yaml | grep -A 20 "operationState"
```

### Infrastructure Status

```bash
# Check MachineSet status
oc get machineset -n openshift-machine-api | grep odf-infra

# Check machine creation
oc get machines -n openshift-machine-api -l machine.openshift.io/cluster-api-machineset | grep odf-infra

# Check node status
oc get nodes -l node-role.kubernetes.io/infra= -o wide
```

### ODF Readiness

```bash
# Verify storage labels
oc get nodes -l cluster.ocs.openshift.io/openshift-storage= --show-labels

# Check rack topology
oc get nodes --show-labels | grep topology.kubernetes.io/rack

# Verify ODF can schedule
oc get pods -n openshift-storage -o wide | grep -E "(osd|mds|mon|noobaa)"
```

## 🚨 **Troubleshooting**

### Common ArgoCD Issues

#### 1. Application Not Syncing

**Symptoms**: Application stuck in OutOfSync or Missing state

**Diagnosis**:
```bash
# Check application events
oc describe application odf-infrastructure -n openshift-gitops

# Check sync logs
oc logs -n openshift-gitops deployment/argocd-application-controller | grep odf-infrastructure
```

**Solutions**:
- Verify repository access and authentication
- Check for YAML syntax errors in component files
- Ensure proper RBAC permissions
- Verify namespace exists (openshift-machine-api)

#### 2. Variable Substitution Issues

**Symptoms**: `${CLUSTER_NAME}` not being replaced

**Diagnosis**:
```bash
# Check if cluster-info ConfigMap exists
oc get configmap cluster-info -n openshift-machine-api

# Verify ConfigMap data
oc get configmap cluster-info -n openshift-machine-api -o yaml
```

**Solutions**:
- Ensure cluster-info ConfigMap is created before other resources
- Verify ConfigMap contains the expected data
- Check kustomize variable configuration

#### 3. Machine API Permission Issues

**Symptoms**: Cannot create MachineSets or Machines

**Diagnosis**:
```bash
# Check ArgoCD service account permissions
oc auth can-i create machinesets --as system:serviceaccount:openshift-gitops:argocd-application-controller

# Check Machine API operator status
oc get clusteroperator machine-api
```

**Solutions**:
- Ensure Machine API operator is healthy
- Grant proper RBAC permissions to ArgoCD
- Verify cluster-admin access for initial setup

### Component-Specific Issues

#### 1. Nodes Not Joining Cluster

**Symptoms**: Machines created but nodes not visible

**Diagnosis**:
```bash
# Check machine status
oc get machines -n openshift-machine-api -l machine.openshift.io/cluster-api-machineset | grep odf-infra

# Check machine events
oc describe machine <machine-name> -n openshift-machine-api
```

**Solutions**:
- Verify vSphere credentials and connectivity
- Check network configuration (VLAN225)
- Ensure RHCOS template is accessible
- Verify resource availability in vSphere

#### 2. ODF Pods Not Scheduling

**Symptoms**: ODF pods stuck in Pending state

**Diagnosis**:
```bash
# Check node labels
oc get nodes -l node-role.kubernetes.io/infra= --show-labels

# Check taints
oc get nodes -l node-role.kubernetes.io/infra= -o yaml | grep -A 5 taints
```

**Solutions**:
- Ensure proper node labels are applied
- Verify taints are correctly configured
- Check resource availability on nodes

## 🔄 **Scaling and Updates**

### Scaling Operations

```bash
# Scale up (increase replicas)
oc patch machineset ${CLUSTER_NAME}-odf-infra -n openshift-machine-api -p '{"spec":{"replicas":4}}'

# Scale down (decrease replicas)
oc patch machineset ${CLUSTER_NAME}-odf-infra -n openshift-machine-api -p '{"spec":{"replicas":3}}'
```

### Component Updates

```bash
# Update component configuration
git commit -am "Update ODF infrastructure configuration"
git push origin main

# ArgoCD will automatically detect changes and sync
# Monitor sync status
oc get application odf-infrastructure -n openshift-gitops -o yaml | grep -A 10 "status:"
```

## 📈 **Performance Optimization**

### Resource Monitoring

```bash
# Monitor node resource utilization
oc adm top nodes -l node-role.kubernetes.io/infra=

# Check Ceph cluster health
oc get cephcluster -n openshift-storage -o yaml | grep -A 5 status

# Monitor storage class usage
oc get pvc --all-namespaces -o wide | grep -E "(ocs|ceph|noobaa)"
```

### Autoscaling Tuning

```bash
# Check autoscaler configuration
oc get machineautoscaler -n openshift-machine-api | grep odf-infra

# View autoscaler events
oc describe machineautoscaler ${CLUSTER_NAME}-odf-infra-autoscaler -n openshift-machine-api
```

## 🚀 **Next Steps After Deployment**

1. **Verify Infrastructure Nodes**: Ensure all 3 nodes are Ready and properly labeled
2. **Deploy ODF Operator**: Enable ODF operator component (Sync Wave 5)
3. **Configure Storage Cluster**: Deploy ODF configuration component (Sync Wave 15)
4. **Test Storage Classes**: Verify RBD and CephFS storage classes are available
5. **Deploy Applications**: Deploy Vault and other applications using ODF storage

## 📚 **Additional Resources**

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenShift Data Foundation Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation)
- [Machine API Documentation](https://docs.openshift.com/container-platform/4.18/machine_management/index.html)
- [Kustomize Documentation](https://kustomize.io/)

---

**Note**: This component is designed to be portable across clusters. Simply update the cluster-specific values in `cluster-info.yaml` and vSphere paths in the MachineSet to deploy to different clusters.
