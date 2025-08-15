# OAuth Configuration with Vault Integration

## 🎯 Overview
This component configures OpenShift OAuth with Azure AD integration, using Vault as the secure source for the Azure AD client secret instead of storing it directly in Kubernetes secrets.

## 🔐 Vault Integration Architecture

### Flow:
1. **VaultStaticSecret** pulls the Azure AD client secret from Vault
2. **VaultStaticSecret** creates a Kubernetes secret with the same name
3. **OAuth configuration** references the Kubernetes secret
4. **OpenShift** uses the secret for Azure AD authentication

### Components:
- **VaultAuth**: Kubernetes authentication method for the OAuth service account
- **VaultConnection**: Connection configuration to the Vault instance
- **VaultStaticSecret**: Automatically syncs Vault secrets to Kubernetes secrets
- **OAuth**: OpenShift OAuth configuration using the synced secret

## 📁 Files

### Core Configuration
- `oauth-cluster-config.yaml` - OpenShift OAuth configuration
- `vault-auth.yaml` - Vault authentication setup
- `vault-connection.yaml` - Vault connection configuration
- `vault-static-secret.yaml` - Secret synchronization from Vault

### Setup Scripts
- `setup-vault-auth.sh` - Configures Vault policies and roles

## 🔑 Security Features

### Vault Policies
- **oauth-policy**: Restricts access to only the Azure AD client secret
- **Scope**: Limited to `openshift-config` namespace
- **Permissions**: Read-only access to specific secret path

### Kubernetes Roles
- **oauth-role**: Binds to specific service account and namespace
- **TTL**: 1-hour token lifetime for security
- **Scope**: Restricted to `openshift-config` namespace only

## 🚀 Deployment Order

The resources are deployed in the following order (via sync waves):

1. **Wave 7**: ServiceAccount creation
2. **Wave 8**: VaultAuth and VaultConnection
3. **Wave 9**: VaultStaticSecret (creates Kubernetes secret)
4. **Wave 10**: OAuth configuration (uses the created secret)

## 🔧 Setup Process

### 1. Prerequisites
- Vault deployed and running in `vault-system` namespace
- Vault Secrets Operator running
- Azure AD client secret stored in Vault at `cluster-secrets/openid-client-secret-azuread`

### 2. Vault Configuration
Run the setup script to configure Vault authentication:
```bash
./setup-vault-auth.sh
```

This script:
- Creates the `oauth-policy` in Vault
- Creates the `oauth-role` for Kubernetes authentication
- Binds the role to the `oauth-vault-auth` service account

### 3. Deploy Resources
Apply the configuration via ArgoCD:
```bash
oc apply -k kohler-openshift/components/oauth-configuration/
```

## 🔍 Verification

### Check VaultStaticSecret Status
```bash
oc get vaultstaticsecret -n openshift-config
oc describe vaultstaticsecret openid-client-secret-azuread -n openshift-config
```

### Check Created Kubernetes Secret
```bash
oc get secret openid-client-secret-azuread -n openshift-config
oc describe secret openid-client-secret-azuread -n openshift-config
```

### Check OAuth Configuration
```bash
oc get oauth cluster -o yaml
```

### Check Vault Authentication
```bash
# From the Vault pod
vault read auth/kubernetes/role/oauth-role
vault policy read oauth-policy
```

## 🛡️ Security Benefits

1. **No Secrets in Git**: Azure AD client secret is never stored in the repository
2. **Centralized Management**: All secrets managed in Vault
3. **Access Control**: Fine-grained policies control who can access secrets
4. **Audit Trail**: All secret access is logged in Vault
5. **Automatic Rotation**: VaultStaticSecret can refresh secrets automatically
6. **Namespace Isolation**: Secrets are only accessible from authorized namespaces

## 🔄 Secret Refresh

The VaultStaticSecret is configured to refresh every hour:
```yaml
refreshAfter: 1h
```

This ensures that:
- Secrets are kept up-to-date
- Any changes in Vault are automatically synced
- Kubernetes secrets remain current

## 🚨 Troubleshooting

### Common Issues

1. **VaultStaticSecret not syncing**
   - Check Vault connection
   - Verify VaultAuth configuration
   - Check service account permissions

2. **OAuth authentication failing**
   - Verify Kubernetes secret exists
   - Check secret format and keys
   - Validate OAuth configuration

3. **Vault authentication errors**
   - Verify Vault policies and roles
   - Check service account binding
   - Validate Kubernetes authentication setup

### Debug Commands

```bash
# Check Vault status
oc exec -n vault-system <vault-pod> -- vault status

# Check Vault authentication
oc exec -n vault-system <vault-pod> -- vault auth list

# Check Vault policies
oc exec -n vault-system <vault-pod> -- vault policy list

# Check VaultStaticSecret logs
oc logs -n vault-secrets-system -l app.kubernetes.io/name=vault-secrets-operator
```

## 📚 References

- [Vault Secrets Operator Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/operator)
- [OpenShift OAuth Configuration](https://docs.openshift.com/container-platform/4.12/authentication/identity_providers/configuring-oidc-identity-provider.html)
- [Vault Kubernetes Authentication](https://developer.hashicorp.com/vault/docs/auth/kubernetes)

---
*Generated on: 2025-08-15*
*Cluster: ocp2-mbh44*
*Environment: Production*
