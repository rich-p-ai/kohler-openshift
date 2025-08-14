# HashiCorp Vault & VSO Deployment Guide for OCP2

This guide provides comprehensive instructions for deploying HashiCorp Vault and Vault Secrets Operator (VSO) on the ocp2 OpenShift cluster.

## 🎯 **Overview**

This deployment provides:
- **HashiCorp Vault**: Enterprise-grade secret management with automated initialization and unsealing
- **Vault Secrets Operator (VSO)**: Kubernetes-native secret management using Vault as the backend
- **GitOps Integration**: Fully automated deployment through ArgoCD
- **Security Best Practices**: Non-root containers, RBAC, and secure authentication

## 🏗️ **Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │    │ Vault Secrets   │    │   HashiCorp     │
│   (Pods/Jobs)   │───▶│   Operator      │───▶│     Vault       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │              ┌─────────────────┐              │
        └─────────────▶│  Kubernetes API │◀─────────────┘
                       │   (Secrets)     │
                       └─────────────────┘
```

## 📋 **Prerequisites**

### 1. Cluster Requirements
- ✅ OpenShift 4.x cluster (ocp2)
- ✅ OpenShift GitOps (ArgoCD) installed
- ✅ ODF storage available for persistent volumes
- ✅ Admin access to the cluster

### 2. Storage Requirements
- **Vault Data**: 10Gi persistent volume (OCS storage class)
- **Storage Class**: `ocs-storagecluster-cephfs`

### 3. Network Requirements
- **Vault UI**: Accessible via OpenShift route
- **Internal Communication**: Service-to-service communication within cluster

## 🚀 **Deployment Steps**

### Step 1: Verify Current Configuration
```bash
# Check if components are already enabled
oc get applications -n openshift-gitops | grep vault

# Check if namespaces exist
oc get namespace | grep vault
```

### Step 2: Apply Vault Applications
The Vault components are configured in the `clusters/ocp2/values.yaml` file and will be deployed automatically through ArgoCD.

```bash
# Monitor the deployment
oc get applications -n openshift-gitops vault-deployment vault-secrets-operator

# Check application sync status
oc describe application vault-deployment -n openshift-gitops
oc describe application vault-secrets-operator -n openshift-gitops
```

### Step 3: Monitor Deployment Progress
```bash
# Watch Vault namespace creation
oc get namespace vault-system --watch

# Watch VSO namespace creation
oc get namespace vault-secrets-system --watch

# Monitor Vault pods
oc get pods -n vault-system --watch

# Monitor VSO pods
oc get pods -n vault-secrets-system --watch
```

## 🔧 **Component Details**

### 1. Vault Deployment (`vault-deployment`)

#### **Sync Wave 1**: Namespace and RBAC
- Creates `vault-system` namespace
- Sets up service account and cluster roles

#### **Sync Wave 2**: Configuration and Storage
- Creates Vault configuration ConfigMap
- Provisions persistent volume claim

#### **Sync Wave 3**: Core Services
- Deploys Vault server
- Creates service and route

#### **Sync Wave 4**: Initialization
- Runs Vault initialization job
- Stores unseal keys and root token

#### **Sync Wave 5**: Unsealing
- Runs Vault unsealing job
- Makes Vault operational

#### **Sync Wave 6**: Configuration
- Configures Kubernetes authentication
- Sets up policies and roles
- Enables secret engines

### 2. Vault Secrets Operator (`vault-secrets-operator`)

#### **Sync Wave 1**: Namespace and Operator
- Creates `vault-secrets-system` namespace
- Deploys VSO operator

#### **Sync Wave 2**: Authentication
- Configures Vault authentication
- Sets up example secret

## 🌐 **Accessing Vault**

### Vault UI Access
```bash
# Get the Vault route
VAULT_URL=$(oc get route vault-ui -n vault-system -o jsonpath='{.spec.host}')
echo "Vault UI: https://$VAULT_URL"

# Access in browser
open "https://$VAULT_URL"
```

### Authentication
```bash
# Get root token (for initial setup only)
ROOT_TOKEN=$(oc get secret vault-root-token -n vault-system -o jsonpath='{.data.root-token}' | base64 -d)
echo "Root Token: $ROOT_TOKEN"

# Set environment variables
export VAULT_ADDR="https://vault-ui-vault-system.apps.ocp2.kohlerco.com"
export VAULT_TOKEN="$ROOT_TOKEN"
```

## 📊 **Verification Commands**

### 1. Check Vault Status
```bash
# Verify Vault is running
oc get pods -n vault-system

# Check Vault status
oc exec -it deployment/vault -n vault-system -- vault status

# Verify secrets are created
oc get secret -n vault-system
```

### 2. Check VSO Status
```bash
# Verify VSO is running
oc get pods -n vault-secrets-system

# Check VSO custom resources
oc get vaultauth -n vault-secrets-system
oc get vaultstaticsecret -n vault-secrets-system

# Verify example secret
oc get secret example-secret -n vault-secrets-system
```

### 3. Test Vault Functionality
```bash
# Test Vault CLI access
vault kv list secret/

# Test secret retrieval
vault kv get secret/example

# Test authentication
vault auth list
```

## 🔐 **Security Configuration**

### 1. Vault Policies
The deployment automatically creates the following policies:

```hcl
# Vault Secrets Operator policy
path "secret/data/*" {
  capabilities = ["read"]
}
path "secret/metadata/*" {
  capabilities = ["read"]
}
path "auth/kubernetes/login" {
  capabilities = ["create", "read"]
}
```

### 2. Kubernetes Authentication
- **Method**: Service account token authentication
- **Role**: `vault-secrets-operator`
- **TTL**: 1 hour token lifetime
- **Namespace**: `vault-secrets-system`

### 3. RBAC Configuration
- **Service Account**: `vault` in `vault-system` namespace
- **Cluster Roles**: Authentication delegation
- **Security Context**: Non-root user (UID 100, GID 1000)

## 📝 **Usage Examples**

### 1. Store Application Secrets
```bash
# Store database credentials
vault kv put secret/applications/myapp \
  database_url="postgresql://db.example.com:5432/myapp" \
  database_username="myapp_user" \
  database_password="secure_password"

# Store API keys
vault kv put secret/applications/myapp \
  api_key="your-api-key" \
  webhook_url="https://webhook.example.com/endpoint"
```

### 2. Create Vault Static Secret
```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: database-credentials
  namespace: my-app
spec:
  type: kv-v2
  mount: secret
  path: applications/myapp
  refreshAfter: 30s
  secretName: database-credentials
  hvs:
    vaultAuthRef: kubernetes
```

### 3. Use Secrets in Applications
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: database_url
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: api_key
```

## 🚨 **Troubleshooting**

### Common Issues

#### 1. Vault Pod Not Starting
```bash
# Check pod status
oc describe pod -l app=vault -n vault-system

# Check logs
oc logs deployment/vault -n vault-system

# Check events
oc get events -n vault-system --sort-by='.lastTimestamp'
```

#### 2. Initialization Job Failed
```bash
# Check job status
oc get jobs -n vault-system

# Check job logs
oc logs job/vault-init -n vault-system

# Check secrets
oc get secret vault-unseal-keys -n vault-system
```

#### 3. Unsealing Job Failed
```bash
# Check job status
oc get jobs -n vault-system

# Check job logs
oc logs job/vault-unseal -n vault-system

# Verify Vault status
oc exec -it deployment/vault -n vault-system -- vault status
```

#### 4. VSO Not Working
```bash
# Check operator status
oc get deployment vault-secrets-operator -n vault-secrets-system

# Check operator logs
oc logs deployment/vault-secrets-operator -n vault-secrets-system

# Check custom resources
oc get vaultauth -n vault-secrets-system
oc get vaultstaticsecret -n vault-secrets-system
```

### Health Check Commands
```bash
# Comprehensive health check
echo "=== VAULT STATUS ==="
oc get pods -n vault-system
oc exec -it deployment/vault -n vault-system -- vault status

echo "=== VSO STATUS ==="
oc get pods -n vault-secrets-system
oc get vaultauth -n vault-secrets-system
oc get vaultstaticsecret -n vault-secrets-system

echo "=== SECRETS ==="
oc get secret -n vault-system
oc get secret -n vault-secrets-system

echo "=== EVENTS ==="
oc get events -n vault-system --sort-by='.lastTimestamp' | tail -10
oc get events -n vault-secrets-system --sort-by='.lastTimestamp' | tail -10
```

## 🔄 **Maintenance**

### 1. Backup Vault Data
```bash
# Backup persistent volume
oc get pvc vault-data -n vault-system

# Export Vault configuration
vault read sys/config/state
vault auth list
vault policy list
```

### 2. Update Vault
```bash
# Update Vault image
oc patch deployment vault -n vault-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"vault","image":"hashicorp/vault:1.16.0"}]}}}}'

# Monitor rollout
oc rollout status deployment/vault -n vault-system
```

### 3. Rotate Unseal Keys
```bash
# Generate new unseal keys
vault operator rekey -init -key-shares=5 -key-threshold=3

# Apply new keys
vault operator rekey
```

## 📚 **Additional Resources**

### Documentation
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Secrets Operator Documentation](https://www.vaultproject.io/docs/platform/k8s/vso)
- [OpenShift Documentation](https://docs.openshift.com/)

### Useful Commands
```bash
# Vault CLI help
vault --help

# Vault operator help
vault operator --help

# Vault auth help
vault auth --help

# Vault policy help
vault policy --help
```

## 🎉 **Success Criteria**

Your Vault deployment is successful when:

1. ✅ **Vault Server**: Running and unsealed
2. ✅ **Vault UI**: Accessible via browser
3. ✅ **VSO Operator**: Running and healthy
4. ✅ **Authentication**: Kubernetes auth working
5. ✅ **Secrets**: Can store and retrieve secrets
6. ✅ **Integration**: VSO can sync secrets from Vault

## 🆘 **Getting Help**

If you encounter issues:

1. **Check the troubleshooting section** above
2. **Review pod logs** for error messages
3. **Check ArgoCD sync status** for deployment issues
4. **Verify prerequisites** are met
5. **Check OpenShift events** for cluster issues

---

**Happy Vaulting! 🗝️**
