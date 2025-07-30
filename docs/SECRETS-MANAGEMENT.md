# Secrets Management Guide

This document explains how to manage sensitive data in the GitOps repository safely.

## 🔐 Secret Handling Strategy

### For Development/Testing (ocp-dev)
For the development cluster, you can use placeholder values or test secrets since this is not production data.

### For Production (ocp-prd)
Production secrets must be handled securely and should NOT be committed to Git.

## 📋 Required Secrets

### 1. Azure AD Client Secret
**File**: `components/oauth-configuration/azure-ad-client-secret.yaml`
**Purpose**: OAuth integration with Azure Active Directory

```bash
# Get the current secret from production cluster
oc extract secret/openid-client-secret-azuread -n openshift-config --to=-

# Apply the secret manually before GitOps deployment
oc apply -f components/oauth-configuration/azure-ad-client-secret.yaml
```

### 2. OADP Backup Storage Credentials
**File**: `components/oadp-configuration/backup-storage-credentials.yaml`
**Purpose**: S3 storage credentials for backup location

```bash
# Apply backup credentials manually
oc apply -f components/oadp-configuration/backup-storage-credentials.yaml
```

## 🚀 Deployment Process

### Option 1: Manual Secret Application (Recommended)
1. Create secrets manually before GitOps deployment:
```bash
# Apply all secrets first
oc apply -f components/oauth-configuration/azure-ad-client-secret.yaml
oc apply -f components/oadp-configuration/backup-storage-credentials.yaml

# Then run GitOps deployment
./scripts/deploy-critical-components.sh
```

### Option 2: External Secret Management
For production environments, consider using:
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/)

### Option 3: Sealed Secrets
Use [Sealed Secrets](https://sealed-secrets.netlify.app/) to encrypt secrets that can be stored in Git:

```bash
# Install kubeseal
# Create sealed secret
echo -n 'your-secret-value' | kubectl create secret generic mysecret --dry-run=client --from-file=secret=/dev/stdin -o yaml | kubeseal -o yaml > mysealedsecret.yaml
```

## 📝 Secret Templates

### Azure AD Client Secret Template
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: openid-client-secret-azuread
  namespace: openshift-config
type: Opaque
stringData:
  clientSecret: "YOUR_AZURE_AD_CLIENT_SECRET_HERE"
```

### OADP S3 Credentials Template
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: openshift-adp
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id=YOUR_ACCESS_KEY
    aws_secret_access_key=YOUR_SECRET_KEY
```

## ⚠️ Security Best Practices

1. **Never commit real secrets to Git**
2. **Use strong, unique passwords/keys**
3. **Rotate secrets regularly**
4. **Use least-privilege access**
5. **Monitor secret access and usage**
6. **Use external secret management for production**

## 🔧 Troubleshooting

### Secret Not Found Errors
```bash
# Check if secret exists
oc get secret SECRET_NAME -n NAMESPACE

# Describe secret for more details
oc describe secret SECRET_NAME -n NAMESPACE

# Re-create secret if needed
oc delete secret SECRET_NAME -n NAMESPACE
oc apply -f path/to/secret.yaml
```

### Permission Errors
```bash
# Check if service account has access
oc auth can-i get secrets --as=system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT

# Create role binding if needed
oc create rolebinding secret-reader --clusterrole=view --serviceaccount=NAMESPACE:SERVICE_ACCOUNT
```
