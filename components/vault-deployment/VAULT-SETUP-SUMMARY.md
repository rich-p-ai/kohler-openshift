# Vault Setup Summary for OCP2 Cluster

## 🎯 Overview
Vault has been successfully deployed and configured on the OCP2 cluster with a dedicated secrets vault for cluster secrets.

## 🔐 Vault Credentials
**⚠️ IMPORTANT: Store these securely - they provide full access to Vault**

- **Unseal Key**: `[REDACTED - Store securely]`
- **Root Token**: `[REDACTED - Store securely]`

## 🌐 Access Information
- **Vault UI URL**: https://vault-ui-vault-system.apps.ocp2.kohlerco.com
- **Vault API**: http://vault.vault-system.svc:8200
- **Namespace**: vault-system

## 🔑 Secrets Configuration

### Secrets Engine: `cluster-secrets/`
Path: `cluster-secrets/` (KV v2)

#### Available Secrets:
1. **openid-client-secret-azuread**
   - Key: `clientSecret`
   - Value: `[REDACTED - Azure AD Client Secret]`
   - Purpose: Azure AD OpenID Connect client secret

2. **cluster-info**
   - Key: `clusterName`
   - Value: `ocp2-mbh44`
   - Key: `clusterDomain`
   - Value: `kohlerco.com`
   - Key: `environment`
   - Value: `production`

## 🔐 Authentication Methods

### Kubernetes Authentication
- **Path**: `auth/kubernetes/`
- **Role**: `cluster-secrets-role`
- **Policy**: `cluster-secrets-policy`
- **Access**: Read access to `cluster-secrets/*`
- **Scope**: All service accounts in all namespaces
- **TTL**: 1 hour

## 📋 Vault Policies

### cluster-secrets-policy
```hcl
path "cluster-secrets/*" {
  capabilities = ["read"]
}
```

## 🚀 Usage Examples

### Access Secrets via CLI
```bash
# Login to Vault
vault login [ROOT_TOKEN]

# List secrets
vault kv list cluster-secrets/

# Get specific secret
vault kv get cluster-secrets/openid-client-secret-azuread

# Get cluster info
vault kv get cluster-secrets/cluster-info
```

### Access Secrets via Kubernetes
```bash
# From a pod with service account
vault write auth/kubernetes/login role=cluster-secrets-role jwt=<service-account-token>

# Then access secrets
vault kv get cluster-secrets/openid-client-secret-azuread
```

## 🔧 Management Commands

### Unseal Vault (if sealed)
```bash
vault operator unseal [UNSEAL_KEY]
```

### Add New Secrets
```bash
# Add new secret
vault kv put cluster-secrets/new-secret-name key1=value1 key2=value2

# Update existing secret
vault kv put cluster-secrets/existing-secret-name key1=new-value
```

### List All Secrets
```bash
vault kv list cluster-secrets/
```

## 🛡️ Security Notes
- Root token provides full access - use sparingly
- Consider creating limited tokens for specific use cases
- Kubernetes authentication is configured for application access
- All secrets are encrypted at rest
- Access is logged and auditable

## 📚 Next Steps
1. **Access Vault UI** to explore the interface
2. **Add more secrets** as needed for your applications
3. **Configure Vault Secrets Operator** for Kubernetes integration
4. **Set up backup and recovery** procedures
5. **Monitor Vault logs** for security events

## 🔍 Troubleshooting

### Check Vault Status
```bash
vault status
```

### Check Authentication Methods
```bash
vault auth list
```

### Check Secrets Engines
```bash
vault secrets list
```

### Check Policies
```bash
vault policy list
```

## 📝 Note on Credentials
The actual Vault credentials and secret values are not stored in this repository for security reasons. 
Store them securely in a password manager or secure location.

---
*Generated on: 2025-08-15*
*Cluster: ocp2-mbh44*
*Environment: Production*
