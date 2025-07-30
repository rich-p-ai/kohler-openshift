# Critical Infrastructure Components Deployment Guide

This guide provides step-by-step instructions for deploying critical infrastructure components to the OCP-DEV cluster using GitOps.

## 🚀 Deployment Overview

### Phase 1: Core Infrastructure Components
These components form the foundation of the cluster and must be deployed first:

1. **GitOps Operator** (Sync Wave 1-3) - Enables self-management
2. **Network Configuration** (Sync Wave 3) - Core networking setup  
3. **GitOps Configuration** (Sync Wave 5) - ArgoCD cluster configuration
4. **Image Registry Configuration** (Sync Wave 8) - Container registry setup

### Phase 2: Storage and Data Protection  
5. **ODF Operator** (Sync Wave 5) - OpenShift Data Foundation
6. **ODF Configuration** (Sync Wave 15) - Storage cluster setup
7. **OADP Operator** (Sync Wave 5) - Backup operator
8. **OADP Configuration** (Sync Wave 15) - Backup configuration
9. **OADP Scheduled Backups** (Sync Wave 25) - Automated backups

### Phase 3: Authentication and Security
10. **OAuth Configuration** (Sync Wave 10) - Azure AD SSO
11. **Cert-Manager Operator** (Sync Wave 5) - Certificate management

## 📋 Prerequisites

### 1. Cluster Access
Ensure you have cluster-admin access to the ocp-dev cluster:
```bash
oc login --server=https://api.ocp-dev.kohlerco.com:6443
oc whoami
oc auth can-i "*" "*" --all-namespaces
```

### 2. Repository Access
Verify access to the GitHub repository:
```bash
git clone https://github.com/rich-p-ai/kohler-openshift.git
cd kohler-openshift
```

### 3. GitOps Operator Bootstrap
The GitOps operator must be manually installed first to enable self-management:
```bash
# Apply GitOps operator directly
oc apply -k components/gitops-operator/
```

### 4. Verify GitOps Operator Installation
```bash
# Wait for operator to be ready
oc get csv -n openshift-gitops-operator | grep gitops
oc get pods -n openshift-gitops-operator

# Verify ArgoCD namespace is created
oc get namespace openshift-gitops
```

## 🔧 Component Deployment Steps

### Step 1: Bootstrap GitOps Configuration
Once the GitOps operator is running, deploy the ArgoCD cluster configuration:
```bash
# Apply GitOps configuration
oc apply -k components/gitops-configuration/

# Wait for ArgoCD to be ready
oc get argocd openshift-gitops -n openshift-gitops
oc get pods -n openshift-gitops
```

### Step 2: Deploy App-of-Apps Pattern
Deploy the main Application that manages all other applications:
```bash
# Deploy the app-of-apps
oc apply -k clusters/dev/

# Verify the application is created
oc get applications -n openshift-gitops
```

### Step 3: Monitor Application Deployment
```bash
# Watch applications sync
oc get applications -n openshift-gitops -w

# Check application status
argocd app list --server openshift-gitops-server-openshift-gitops.apps.ocp-dev.kohlerco.com

# View ArgoCD UI
echo "ArgoCD UI: https://openshift-gitops-server-openshift-gitops.apps.ocp-dev.kohlerco.com"
```

## 🔍 Verification Commands

### Verify Core Infrastructure
```bash
# Check GitOps components
oc get pods -n openshift-gitops
oc get pods -n openshift-gitops-operator

# Check network configuration
oc get network cluster -o yaml
oc get ingresscontroller default -n openshift-ingress-operator -o yaml

# Check image registry
oc get config.imageregistry.operator.openshift.io/cluster -o yaml
oc get pods -n openshift-image-registry
```

### Verify Storage Components
```bash
# Check ODF components
oc get csv -n openshift-storage | grep odf
oc get storagecluster -n openshift-storage
oc get pods -n openshift-storage

# Check storage classes
oc get storageclass
```

### Verify Backup Components
```bash
# Check OADP components
oc get csv -n openshift-adp | grep oadp
oc get dataprotectionapplication -n openshift-adp
oc get schedule -n openshift-adp
```

### Verify Authentication
```bash
# Check OAuth configuration
oc get oauth cluster -o yaml
oc get secrets -n openshift-config | grep azure
```

## 🚨 Troubleshooting

### Common Issues

#### 1. GitOps Operator Installation Fails
```bash
# Check operator logs
oc logs -n openshift-gitops-operator deployment/openshift-gitops-operator-controller-manager

# Verify subscription
oc get subscription openshift-gitops-operator -n openshift-gitops-operator -o yaml
```

#### 2. ArgoCD Applications Not Syncing
```bash
# Check ArgoCD server logs
oc logs -n openshift-gitops deployment/openshift-gitops-server

# Check application controller logs
oc logs -n openshift-gitops deployment/openshift-gitops-application-controller
```

#### 3. Storage Configuration Issues
```bash
# Check storage operator logs
oc logs -n openshift-storage deployment/odf-operator-controller-manager

# Verify storage class exists
oc get storageclass thin-csi
```

#### 4. Network Configuration Problems
```bash
# Check cluster network status
oc get clusteroperator network

# Check ingress controller status
oc get clusteroperator ingress
```

## 📊 Expected Results

After successful deployment, you should have:
- ✅ GitOps operator managing cluster configuration
- ✅ ArgoCD UI accessible with cluster admin access
- ✅ All 11 applications deployed and synced
- ✅ Storage classes available (thin-csi, ocs-storagecluster-ceph-rbd, etc.)
- ✅ Image registry operational with persistent storage
- ✅ Backup schedules configured and running
- ✅ Azure AD SSO authentication working
- ✅ Certificate management operational

## 🔄 Next Steps

1. **Monitor Application Health**: Use ArgoCD UI to monitor all applications
2. **Test Backup Functionality**: Verify backup schedules are working
3. **Test Storage**: Create test PVCs using ODF storage classes
4. **Test Authentication**: Login using Azure AD credentials
5. **Add Additional Components**: Deploy remaining infrastructure components from Phase 2

## 📚 Documentation Links

- [OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/4.16/cicd/gitops/understanding-openshift-gitops.html)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ODF Documentation](https://docs.openshift.com/container-platform/4.16/storage/persistent_storage/persistent_storage_ocs.html)
- [OADP Documentation](https://docs.openshift.com/container-platform/4.16/backup_and_restore/application_backup_and_restore/oadp-features-plugins.html)
