# 🚀 MTC Quick Start Guide

## ⚡ Get Started in 5 Minutes

### 1. Run the Setup Script
```bash
cd kohler-openshift/components/mtc-operator
./setup-mtc.sh
```

Choose option **5** for full setup.

### 2. Update Service Account Tokens
The script will output service account tokens. Update these files:
- `ocp-prd-source-secret.yaml` - Replace `saToken` with ocp-prd token
- `ocp2-target-secret.yaml` - Replace `saToken` with ocp2 token

### 3. Deploy via ArgoCD
```bash
oc apply -f argocd-application.yaml
```

### 4. Verify Installation
```bash
oc get csv -n openshift-migration
oc get migcluster -n openshift-migration
```

## 🎯 What This Sets Up

- ✅ MTC operator in `openshift-migration` namespace
- ✅ Source cluster configuration (ocp-prd)
- ✅ Target cluster configuration (ocp2)
- ✅ Service accounts with proper permissions
- ✅ ArgoCD application for GitOps deployment

## 📋 Next Steps

1. **Create Migration Plan** - Define which namespaces to migrate
2. **Configure Storage** - Set up backup storage for migrations
3. **Execute Migration** - Run the actual migration process

## 🔧 Troubleshooting

If you encounter issues:

### **Setup Script Fails:**
1. **Test connectivity first:**
   ```bash
   ./test-cluster-connectivity.sh
   ```
2. **Use manual setup:**
   ```bash
   # Follow MANUAL-SETUP.md instead
   ```

### **General Issues:**
1. Check operator logs: `oc logs -n openshift-migration deployment/mtc-operator`
2. Verify cluster connectivity
3. Ensure service account tokens are correct
4. Check namespace permissions

### **Cluster Login Issues:**
- Verify passwords in `clusters/ocp-prd/env` and `clusters/ocp2/env`
- Check network connectivity to both clusters
- Ensure clusters are running and accessible

## 📚 Full Documentation

See `README.md` for comprehensive setup and migration instructions.
