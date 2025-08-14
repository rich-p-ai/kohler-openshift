# OpenShift OAuth Configuration

This component configures authentication for the OpenShift cluster using Azure Active Directory (Azure AD) as the identity provider for Single Sign-On (SSO).

## Current Configuration

### Azure AD SSO (Primary)
- **Purpose**: Corporate single sign-on integration
- **Status**: Configured and ready for use
- **Provider Type**: OpenID Connect
- **Client ID**: `667e7b9c-e03e-4967-a9fd-953fef9cbce6`
- **Tenant ID**: `5d2d3f03-286e-4643-8f5b-10565608e5f8`

## Azure AD Setup Requirements

### 1. Azure AD Application Registration
- **Application Type**: Web application
- **Redirect URIs**: `https://oauth-openshift.apps.ocp2.kohlerco.com/oauth2callback/azureadsso`
- **Required Claims**: email, name, upn
- **API Permissions**: Microsoft Graph User.Read

### 2. Client Secret Management
The Azure AD client secret must be manually configured in the cluster:

```bash
# Create the secret with your actual Azure AD client secret
oc create secret generic openid-client-secret-azuread \
  --from-literal=clientSecret="YOUR_REAL_AZURE_AD_CLIENT_SECRET" \
  -n openshift-config \
  --dry-run=client -o yaml | oc apply -f -
```

### 3. Restart OAuth Server
After updating the secret, restart the OAuth server:

```bash
oc rollout restart deployment/oauth-openshift -n openshift-authentication
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

## Troubleshooting

### OAuth Server Issues
```bash
# Check OAuth server status
oc get pods -n openshift-authentication

# Check OAuth logs
oc logs -n openshift-authentication deployment/oauth-openshift

# Check authentication operator
oc get clusteroperator authentication
```

### Identity Provider Issues
```bash
# Check OAuth configuration
oc get oauth cluster -o yaml

# Check Azure AD secret
oc get secret openid-client-secret-azuread -n openshift-config
```

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

## Configuration Parameters

### OpenShift OAuth Settings
- **Token Max Age**: Default (24 hours)
- **Access Token Inactivity Timeout**: Default (5 minutes)
- **Session Cookie**: Secure, HttpOnly, SameSite=Lax

## Related Documentation

- [OpenShift OAuth Documentation](https://docs.openshift.com/container-platform/latest/authentication/understanding-authentication.html)
- [Azure AD Application Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [OpenID Connect with Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)
