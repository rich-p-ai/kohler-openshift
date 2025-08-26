# Migration Toolkit for Containers (MTC) Setup

This directory contains the configuration for setting up MTC to migrate applications from **ocp-prd** to **ocp2**.

## 🎯 Migration Direction
- **Source Cluster**: ocp-prd (current production cluster)
- **Target Cluster**: ocp2 (destination cluster)

## 📁 Configuration Files

### Core MTC Components
- `namespace.yaml` - Openshift-migration namespace
- `operator-group.yaml` - Operator group for MTC
- `subscription.yaml` - MTC operator subscription
- `migration-cluster-source.yaml` - ocp-prd source cluster config
- `migration-cluster.yaml` - ocp2 target cluster config
- `migration-storage.yaml` - Storage configuration for backups
- `ocp-prd-source-secret.yaml` - Service account secret for ocp-prd
- `ocp2-target-secret.yaml` - Service account secret for ocp2
- `argocd-application.yaml` - ArgoCD application definition

## 🚀 Setup Steps

### 1. Create Service Accounts in Both Clusters

#### In ocp-prd (Source):
```bash
# Login to ocp-prd
oc login -u kubeadmin -p NKUHNz-u7GkB-rZFdo-u6FVV --server=https://api.ocp-prd.kohlerco.com:6443

# Create namespace and service account
oc create namespace openshift-migration
oc create serviceaccount migration-sa -n openshift-migration
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-migration:migration-sa

# Get the service account token
oc get secret $(oc get sa migration-sa -n openshift-migration -o jsonpath='{.secrets[0].name}') -n openshift-migration -o jsonpath='{.data.token}' | base64 -d
```

#### In ocp2 (Target):
```bash
# Login to ocp2
oc login -u kubeadmin -p FUKeF-MWGqX-H52Et-8wx5T --server=https://api.ocp2.kohlerco.com:6443

# Create namespace and service account
oc create namespace openshift-migration
oc create serviceaccount migration-sa -n openshift-migration
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-migration:migration-sa

# Get the service account token
oc get secret $(oc get sa migration-sa -n openshift-migration -o jsonpath='{.secrets[0].name}') -n openshift-migration -o jsonpath='{.data.token}' | base64 -d
```

### 2. Update Service Account Secrets

Update the `saToken` field in both secret files with the actual tokens from step 1.

### 3. Deploy via ArgoCD

```bash
# Apply the ArgoCD application
oc apply -f argocd-application.yaml
```

### 4. Verify MTC Installation

```bash
# Check operator status
oc get csv -n openshift-migration

# Check migration clusters
oc get migcluster -n openshift-migration

# Check migration storage
oc get migstorage -n openshift-migration
```

## 🔧 Migration Process

### 1. Create Migration Plan
```yaml
apiVersion: migration.openshift.io/v1alpha1
kind: MigPlan
metadata:
  name: ocp-prd-to-ocp2-migration
  namespace: openshift-migration
spec:
  sourceMigClusterRef:
    name: ocp-prd-source-cluster
  destinationMigClusterRef:
    name: ocp2-target-cluster
  sourceMigStorageRef:
    name: migration-storage
  destinationMigStorageRef:
    name: migration-storage
  namespaces:
  - your-app-namespace
```

### 2. Execute Migration
```bash
# Create migration plan
oc apply -f migration-plan.yaml

# Start migration
oc create -f - <<EOF
apiVersion: migration.openshift.io/v1alpha1
kind: MigMigration
metadata:
  name: ocp-prd-to-ocp2-migration
  namespace: openshift-migration
spec:
  migPlanRef:
    name: ocp-prd-to-ocp2-migration
EOF
```

## 📋 Prerequisites

- Both clusters must be accessible
- Service accounts with cluster-admin permissions
- Storage configured for backups
- Network connectivity between clusters
- MTC operator installed and running

## 🚨 Important Notes

- **Backup First**: Always backup your applications before migration
- **Test Migration**: Test with non-critical applications first
- **Storage Classes**: Ensure compatible storage classes exist in target cluster
- **Network Policies**: Verify network policies allow migration traffic
- **Resource Limits**: Check resource availability in target cluster

## 🔍 Troubleshooting

### Common Issues:
1. **Service Account Permissions**: Ensure proper RBAC setup
2. **Network Connectivity**: Verify cluster-to-cluster communication
3. **Storage Configuration**: Check backup storage accessibility
4. **Resource Conflicts**: Resolve namespace/name conflicts

### Debug Commands:
```bash
# Check operator logs
oc logs -n openshift-migration deployment/mtc-operator

# Check migration status
oc get migmigration -n openshift-migration

# Check cluster connectivity
oc get migcluster -n openshift-migration -o yaml
```
