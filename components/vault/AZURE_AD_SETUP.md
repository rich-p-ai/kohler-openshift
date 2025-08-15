# Azure AD Authentication Setup for Vault

This guide explains how to configure Vault to use Azure AD (Azure Active Directory) authentication, allowing users to log in with the same credentials they use for OpenShift.

## Prerequisites

- Azure AD tenant with administrative access
- Azure CLI installed and authenticated
- Vault running and accessible

## Step 1: Create Azure AD App Registration

1. **Go to Azure Portal** → **Azure Active Directory** → **App registrations**

2. **Create new registration**:
   - Name: `Vault-Auth`
   - Supported account types: `Accounts in this organizational directory only`
   - Redirect URI: `Web` → `https://vault-vault.apps.ocp2.kohlerco.com/ui/auth/azure/callback`

3. **Note down the following values**:
   - Application (client) ID
   - Directory (tenant) ID

## Step 2: Create Service Principal

1. **Create a service principal**:
   ```bash
   az ad sp create --id <APPLICATION_ID>
   ```

2. **Note down the Service Principal ID** (Object ID)

## Step 3: Configure Vault Azure Secret

1. **Update the secret** with your Azure AD values:
   ```bash
   oc patch secret vault-azure-config -n vault --type='merge' -p='
   stringData:
     tenant-id: "YOUR_AZURE_TENANT_ID"
     service-principal-id: "YOUR_SERVICE_PRINCIPAL_ID"
   '
   ```

2. **Or manually edit the secret**:
   ```bash
   oc edit secret vault-azure-config -n vault
   ```

## Step 4: Deploy Configuration

1. **Commit and push your changes**:
   ```bash
   git add .
   git commit -m "Add Azure AD authentication configuration"
   git push
   ```

2. **Wait for ArgoCD to sync** or manually apply:
   ```bash
   oc apply -f components/vault/
   ```

## Step 5: Test Azure AD Authentication

1. **Access Vault UI**: Navigate to `https://vault-vault.apps.ocp2.kohlerco.com`

2. **Select Azure AD login method**

3. **Sign in with your Azure AD credentials**

## Configuration Details

### What Gets Configured

- **Azure AD auth method** enabled at `/auth/azure`
- **Azure AD role** `azure-users` with appropriate policies
- **User policy** `azure-user-policy` with access to:
  - `secret/*` - Read/list access to default secrets
  - `apps/*` - Read/list access to application secrets
  - `auth/azure/login` - Ability to authenticate

### Security Features

- **TTL**: 8 hours (configurable)
- **Max TTL**: 24 hours
- **Bound to specific service principal** for security
- **Policy-based access control**

## Troubleshooting

### Common Issues

1. **"Invalid tenant ID"**: Verify your Azure tenant ID
2. **"Service principal not found"**: Ensure service principal exists and ID is correct
3. **"Redirect URI mismatch"**: Check the callback URL in Azure AD app registration

### Debug Commands

```bash
# Check Vault auth methods
oc exec -n vault vault-0 -- vault auth list

# Check Azure AD configuration
oc exec -n vault vault-0 -- vault read auth/azure/config

# Check Azure AD roles
oc exec -n vault vault-0 -- vault list auth/azure/role

# Check policies
oc exec -n vault vault-0 -- vault policy list
```

## Integration with OpenShift

This setup allows users to:
- **Use the same Azure AD credentials** for both OpenShift and Vault
- **Maintain consistent authentication** across your platform
- **Leverage existing Azure AD groups** for access control
- **Use conditional access policies** and MFA configured in Azure AD

## Next Steps

After Azure AD authentication is working:
1. **Create Azure AD groups** for different access levels
2. **Map groups to Vault policies** for fine-grained access control
3. **Configure conditional access** policies in Azure AD
4. **Set up monitoring** and audit logging
