# 🔧 Manual MTC Setup Guide

## 🚨 **If the setup script fails, use this manual approach**

### 📋 **Prerequisites Check**
First, test cluster connectivity:
```bash
cd kohler-openshift/components/mtc-operator
./test-cluster-connectivity.sh
```

### 🎯 **Step 1: Setup ocp-prd (Source Cluster)**

```bash
# Login to ocp-prd manually
oc login -u kubeadmin -p KUHNz-u7GkB-rZFdo-u6FVV --server=https://api.ocp-prd.kohlerco.com:6443 --insecure-skip-tls-verify

# Create namespace and service account
oc create namespace openshift-migration
oc create serviceaccount migration-sa -n openshift-migration
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-migration:migration-sa

# Get the service account token
SA_SECRET=$(oc get sa migration-sa -n openshift-migration -o jsonpath='{.secrets[0].name}')
SA_TOKEN=$(oc get secret $SA_SECRET -n openshift-migration -o jsonpath='{.data.token}' | base64 -d)
echo "ocp-prd Service Account Token: $SA_TOKEN"
```

### 🎯 **Step 2: Setup ocp2 (Target Cluster)**

```bash
# Login to ocp2 manually
oc login -u kubeadmin -p FUKeF-MWGqX-H52Et-8wx5T --server=https://api.ocp2.kohlerco.com:6443 --insecure-skip-tls-verify

# Create namespace and service account
oc create namespace openshift-migration
oc create serviceaccount migration-sa -n openshift-migration
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-migration:migration-sa

# Get the service account token
SA_SECRET=$(oc get sa migration-sa -n openshift-migration -o jsonpath='{.secrets[0].name}')
SA_TOKEN=$(oc get secret $SA_SECRET -n openshift-migration -o jsonpath='{.data.token}' | base64 -d)
echo "ocp2 Service Account Token: $SA_TOKEN"
```

### 🔑 **Step 3: Update Secret Files**

1. **Update `ocp-prd-source-secret.yaml`:**
   ```yaml
   stringData:
     saToken: |
       YOUR_OCP_PRD_TOKEN_HERE
   ```

2. **Update `ocp2-target-secret.yaml`:**
   ```yaml
   stringData:
     saToken: |
       YOUR_OCP2_TOKEN_HERE
   ```

### 🚀 **Step 4: Deploy MTC Operator**

```bash
# Login to ocp-prd (where you want to install MTC)
oc login -u kubeadmin -p KUHNz-u7GkB-rZFdo-u6FVV --server=https://api.ocp-prd.kohlerco.com:6443 --insecure-skip-tls-verify

# Apply MTC configurations
oc apply -f namespace.yaml
oc apply -f operator-group.yaml
oc apply -f subscription.yaml

# Wait for operator to be ready
oc wait --for=condition=Installed csv/mtc-operator -n openshift-migration --timeout=300s
```

### 🔧 **Step 5: Configure Migration Clusters**

```bash
# Apply cluster configurations
oc apply -f migration-cluster-source.yaml
oc apply -f migration-cluster.yaml

# Apply storage configuration
oc apply -f migration-storage.yaml

# Apply secrets (after updating tokens)
oc apply -f ocp-prd-source-secret.yaml
oc apply -f ocp2-target-secret.yaml
```

### ✅ **Step 6: Verify Setup**

```bash
# Check operator status
oc get csv -n openshift-migration

# Check migration clusters
oc get migcluster -n openshift-migration

# Check migration storage
oc get migstorage -n openshift-migration
```

### 🎯 **Step 7: Deploy via ArgoCD (Optional)**

```bash
# Apply ArgoCD application
oc apply -f argocd-application.yaml
```

## 🔍 **Troubleshooting**

### **Login Issues:**
- Verify passwords are correct
- Check network connectivity
- Ensure clusters are running

### **Permission Issues:**
- Verify service accounts have cluster-admin role
- Check namespace exists

### **Operator Issues:**
- Check operator logs: `oc logs -n openshift-migration deployment/mtc-operator`
- Verify subscription status

## 📚 **Next Steps**

After successful setup:
1. Create migration plan
2. Configure storage for backups
3. Execute migration

See `README.md` for detailed migration instructions.
