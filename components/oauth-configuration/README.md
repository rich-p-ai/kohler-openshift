# OAuth Configuration for Azure AD SSO

This component configures OpenShift OAuth to use Azure Active Directory (Azure AD) as the identity provider for Single Sign-On (SSO).

## Component Structure

The OAuth configuration is implemented as a single GitOps component (sync wave 10):

### OAuth Configuration Component (Sync Wave 10)
**Location**: `components/oauth-configuration/`

Configures OAuth cluster resource with Azure AD integration:
- Azure AD client secret management
- OAuth cluster configuration with Azure AD OpenID Connect provider
- Claims mapping for email, name, and UPN (User Principal Name)

## Azure AD Configuration

### Identity Provider Details
- **Provider Type**: OpenID Connect
- **Identity Provider Name**: `azureadsso`
- **Client ID**: `667e7b9c-e03e-4967-a9fd-953fef9cbce6`
- **Tenant ID**: `5d2d3f03-286e-4643-8f5b-10565608e5f8`
- **Issuer URL**: `https://login.microsoftonline.com/5d2d3f03-286e-4643-8f5b-10565608e5f8`

### Claims Mapping
- **Email**: Mapped from `email` claim
- **Name**: Mapped from `name` claim  
- **Preferred Username**: Mapped from `upn` (User Principal Name) claim
- **Mapping Method**: `claim` (automatic mapping based on claims)

## Security Configuration

### Client Secret Management
- **Secret Name**: `openid-client-secret-azuread`
- **Secret Namespace**: `openshift-config`
- **Secret Type**: Opaque
- **Client Secret**: Stored as `clientSecret` key in the secret

> **Note**: The actual client secret value needs to be manually updated in the secret after deployment or managed through external secret management tools.

## Deployment via ArgoCD

The OAuth configuration is deployed at sync wave 10 to ensure it's configured after core cluster components but before applications that might depend on authentication.

## Verification Commands

### Check OAuth Configuration
```bash
# Check current OAuth configuration
oc get oauth cluster -o yaml

# Verify identity provider configuration
oc get oauth cluster -o jsonpath='{.spec.identityProviders[0]}'
```

### Check Client Secret
```bash
# Verify the client secret exists
oc get secret openid-client-secret-azuread -n openshift-config

# Check secret contents (without revealing the value)
oc describe secret openid-client-secret-azuread -n openshift-config
```

### Test Authentication
```bash
# Check OAuth pods status
oc get pods -n openshift-authentication

# View OAuth operator logs
oc logs -n openshift-authentication deployment/oauth-openshift
```

## User Experience

### Login Process
1. Users navigate to the OpenShift web console
2. Click "azureadsso" identity provider
3. Redirected to Microsoft Azure AD login page
4. Enter Azure AD credentials
5. Redirected back to OpenShift with authenticated session

### User Attributes
- **Username**: Derived from UPN (e.g., user@kohlerco.com)
- **Display Name**: Derived from Azure AD name field
- **Email**: Derived from Azure AD email field

## RBAC Integration

After OAuth configuration, users authenticate through Azure AD but still need OpenShift RBAC permissions:

### Grant Cluster Admin Access
```bash
# Add user as cluster admin
oc adm policy add-cluster-role-to-user cluster-admin user@kohlerco.com
```

### Grant Project Access
```bash
# Add user to specific project
oc adm policy add-role-to-user admin user@kohlerco.com -n project-name
```

### Group-based Access
```bash
# Create group and add users
oc adm groups new kohler-admins user1@kohlerco.com user2@kohlerco.com

# Grant permissions to group
oc adm policy add-cluster-role-to-group cluster-admin kohler-admins
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   ```bash
   # Check OAuth operator status
   oc get clusteroperator authentication
   
   # Check OAuth pod logs
   oc logs -n openshift-authentication deployment/oauth-openshift
   ```

2. **Invalid Client Secret**
   ```bash
   # Update client secret
   oc create secret generic openid-client-secret-azuread \
     --from-literal=clientSecret=NEW_SECRET_VALUE \
     --namespace=openshift-config \
     --dry-run=client -o yaml | oc apply -f -
   ```

3. **Claims Mapping Issues**
   ```bash
   # Check user identity after login
   oc get users
   oc get identities
   ```

### OAuth Operator Restart
```bash
# Force OAuth operator to reload configuration
oc delete pods -n openshift-authentication -l app=oauth-openshift
```

## Security Considerations

1. **Client Secret Rotation**
   - Regularly rotate the Azure AD application client secret
   - Update the OpenShift secret accordingly
   - Test authentication after rotation

2. **Access Control**
   - Implement least-privilege RBAC policies
   - Regular audit of user permissions
   - Use groups for managing permissions at scale

3. **Session Management**
   - Configure appropriate session timeouts
   - Monitor authentication logs
   - Implement proper logout procedures

## Configuration Parameters

### Azure AD Application Requirements
- **Application Type**: Web application
- **Redirect URIs**: `https://oauth-openshift.apps.ocp-prd.kohlerco.com/oauth2callback/azureadsso`
- **Required Claims**: email, name, upn
- **API Permissions**: Microsoft Graph User.Read

### OpenShift OAuth Settings
- **Token Max Age**: Default (24 hours)
- **Access Token Inactivity Timeout**: Default (5 minutes)
- **Session Cookie**: Secure, HttpOnly, SameSite=Lax

## Related Documentation

- [OpenShift OAuth Documentation](https://docs.openshift.com/container-platform/latest/authentication/understanding-authentication.html)
- [Azure AD Application Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [OpenID Connect with Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)
