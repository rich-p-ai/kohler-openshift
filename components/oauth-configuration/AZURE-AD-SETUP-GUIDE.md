# Azure AD SSO Setup Guide for OpenShift

## 🎯 Overview
This guide explains how to configure Azure AD SSO for OpenShift with group claims and role-based access control.

## 🔐 Azure AD Application Configuration

### Application Details
- **Application Name**: `ocp-azuread-auth`
- **Application ID**: `8bc87509-6d01-4739-b120-e84019342d66`
- **Object ID**: `172a89e3-ee66-4b9f-82a6-41c591c95d97`

### Required Azure AD Permissions

#### 1. API Permissions
The Azure AD application needs the following Microsoft Graph permissions:

- **Application Permissions**:
  - `Group.Read.All` - Read all groups
  - `User.Read.All` - Read all users

- **Delegated Permissions**:
  - `Group.Read.All` - Read all groups
  - `User.Read.All` - Read all users

#### 2. Authentication Configuration
- **Redirect URIs**: 
  - `https://oauth-openshift-openshift-authentication.apps.ocp2.kohlerco.com/oauth2callback/azureadsso`
  - `https://oauth-openshift-openshift-authentication.apps.ocp2.kohlerco.com/oauth2callback/azureadsso/`

- **Supported Account Types**: 
  - `Accounts in this organizational directory only`

#### 3. Token Configuration
- **Access Token**: Include `groups` claim
- **ID Token**: Include `groups` claim
- **Group Claims**: 
  - Source: `Security groups`
  - Filter: `All groups`

## 👥 Azure AD Groups

### Admin Group
- **Group Name**: `Azure_OpenShift_Admins`
- **Object ID**: `dff67b8f-e712-48af-b815-5d5162f0c598`
- **OpenShift Role**: `cluster-admin`
- **Purpose**: Full cluster administration access

### User Group
- **Group Name**: `Azure_OpenShift_Users`
- **Object ID**: `0d636d19-3489-4af3-8eb3-efbbc8d677e0`
- **OpenShift Role**: `basic-user`
- **Purpose**: Basic cluster access for developers

## 🔧 OpenShift Configuration

### OAuth Configuration
The OAuth configuration includes:
- **Group Claims**: Maps Azure AD groups to OpenShift groups
- **Extra Scopes**: Includes `groups` scope for group information
- **Client ID**: Updated to use the correct Azure AD application ID

### Group Mapping
- **Azure_OpenShift_Admins** → `azure-openshift-admins` (cluster-admin)
- **Azure_OpenShift_Users** → `azure-openshift-users` (basic-user)

### Sync Waves
1. **Wave 7**: ServiceAccount creation
2. **Wave 8**: VaultAuth and VaultConnection
3. **Wave 9**: VaultStaticSecret (creates Kubernetes secret)
4. **Wave 10**: OAuth configuration (uses the created secret)
5. **Wave 11**: Group creation
6. **Wave 12**: Role bindings

## 🚀 Deployment Steps

### 1. Azure AD Configuration
1. Go to Azure Portal → Azure Active Directory → App registrations
2. Find the `ocp-azuread-auth` application
3. Configure API permissions as listed above
4. Update authentication redirect URIs
5. Configure token claims to include groups

### 2. Deploy OpenShift Configuration
```bash
# Apply the configuration
oc apply -k kohler-openshift/components/oauth-configuration/
```

### 3. Verify Configuration
```bash
# Check OAuth configuration
oc get oauth cluster -o yaml

# Check groups
oc get groups

# Check role bindings
oc get clusterrolebindings | grep azure
```

## 🔍 Testing the Configuration

### 1. Test User Login
1. Go to OpenShift console
2. Click "Log in with Azure AD"
3. Authenticate with Azure AD credentials
4. Verify user is assigned to correct group

### 2. Verify Group Membership
```bash
# Check user's group membership
oc get user <username> -o yaml

# Check group members
oc get group azure-openshift-admins -o yaml
oc get group azure-openshift-users -o yaml
```

### 3. Test Role Access
```bash
# Test admin access (should work for admin group members)
oc get nodes

# Test user access (should work for user group members)
oc get projects
```

## 🛡️ Security Considerations

### 1. Group Membership Control
- Only users in the specified Azure AD groups can access OpenShift
- Group membership is controlled in Azure AD
- Changes in Azure AD are reflected in OpenShift on next login

### 2. Role Assignment
- **Admins**: Full cluster access (cluster-admin)
- **Users**: Basic access (basic-user)
- Consider creating custom roles for specific needs

### 3. Audit and Monitoring
- All authentication events are logged
- Group membership changes are tracked
- Monitor for unauthorized access attempts

## 🚨 Troubleshooting

### Common Issues

1. **Groups Not Appearing**
   - Check Azure AD API permissions
   - Verify group claims configuration
   - Check OAuth logs for errors

2. **Authentication Fails**
   - Verify redirect URIs in Azure AD
   - Check client secret configuration
   - Verify issuer URL

3. **Role Access Denied**
   - Check group membership in Azure AD
   - Verify role bindings in OpenShift
   - Check user's group assignments

### Debug Commands

```bash
# Check OAuth operator logs
oc logs -n openshift-authentication -l app=oauth-openshift

# Check authentication events
oc get events -n openshift-config

# Verify OAuth configuration
oc get oauth cluster -o yaml

# Check group mappings
oc get groups
oc get clusterrolebindings | grep azure
```

## 📚 References

- [OpenShift OAuth Configuration](https://docs.openshift.com/container-platform/4.12/authentication/identity_providers/configuring-oidc-identity-provider.html)
- [Azure AD App Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Azure AD Group Claims](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-optional-claims)

---
*Generated on: 2025-08-15*
*Cluster: ocp2-mbh44*
*Environment: Production*
