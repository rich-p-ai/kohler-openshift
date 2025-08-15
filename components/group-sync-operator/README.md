# Group Sync Operator Component

## 🎯 Overview
The Group Sync Operator automatically synchronizes Azure AD groups to OpenShift, providing dynamic group management and ensuring that group membership changes in Azure AD are automatically reflected in OpenShift.

## 🔧 What It Does

### **Automatic Group Synchronization**
- **Real-time Sync**: Automatically syncs Azure AD groups to OpenShift every 30 minutes
- **Dynamic Updates**: Group membership changes in Azure AD are immediately reflected in OpenShift
- **Pruning**: Removes groups that no longer exist in Azure AD
- **Filtering**: Only syncs groups matching the pattern `Azure_OpenShift_*`

### **Azure AD Integration**
- **Authentication**: Uses Azure AD application credentials for secure access
- **Group Filtering**: Automatically discovers and syncs relevant groups
- **User Filtering**: Only syncs enabled user accounts
- **Tenant Isolation**: Works within your specific Azure AD tenant

## 📁 Component Structure

```
group-sync-operator/
├── namespace.yaml                    # Namespace for the operator
├── operator-group.yaml              # OperatorGroup configuration
├── subscription.yaml                # Operator subscription
├── azure-ad-credentials-secret.yaml # Azure AD credentials
├── azure-ad-groupsync.yaml         # GroupSync configuration
├── kustomization.yaml              # Kustomize configuration
└── README.md                       # This documentation
```

## 🚀 Deployment Order (Sync Waves)

1. **Wave 1**: Namespace creation
2. **Wave 2**: OperatorGroup setup
3. **Wave 3**: Operator subscription
4. **Wave 4**: Azure AD credentials secret
5. **Wave 5**: GroupSync configuration

## 🔐 Azure AD Configuration

### **Required Permissions**
The Azure AD application needs the following Microsoft Graph permissions:

- **Application Permissions**:
  - `Group.Read.All` - Read all groups
  - `User.Read.All` - Read all users
  - `Directory.Read.All` - Read directory data

- **Delegated Permissions**:
  - `Group.Read.All` - Read all groups
  - `User.Read.All` - Read all users

### **Application Details**
- **Application Name**: `aro-auth`
- **Application ID**: `667e7b9c-e03e-4967-a9fd-953fef9cbce6`
- **Object ID**: `bd6342de-712e-4bc0-a954-9c97dfd5acf0`
- **Tenant ID**: `5d2d3f03-286e-4643-8f5b-10565608e6`

## 👥 Group Synchronization

### **Group Filtering**
The operator uses the following filter to identify relevant groups:
```
displayName -like 'Azure_OpenShift_*'
```

This means it will automatically sync groups like:
- `Azure_OpenShift_Admins`
- `Azure_OpenShift_Users`
- `Azure_OpenShift_Developers`
- Any other group starting with `Azure_OpenShift_`

### **User Filtering**
Only enabled users are synced:
```
accountEnabled eq true
```

### **Sync Schedule**
Groups are synchronized every 30 minutes:
```
schedule: "*/30 * * * *"
```

## 🔄 How It Works

### **1. Discovery Phase**
- Operator connects to Azure AD using configured credentials
- Discovers groups matching the filter pattern
- Identifies group members

### **2. Synchronization Phase**
- Creates OpenShift groups for discovered Azure AD groups
- Adds/removes users based on current Azure AD membership
- Updates group metadata

### **3. Pruning Phase**
- Removes groups that no longer exist in Azure AD
- Removes users who are no longer members
- Maintains consistency between Azure AD and OpenShift

## 🛡️ Security Features

### **Credential Management**
- Azure AD credentials stored in Kubernetes secrets
- No hardcoded secrets in Git
- Can be integrated with Vault for enhanced security

### **Access Control**
- Operator runs in dedicated namespace
- Minimal required permissions
- Audit logging for all operations

### **Data Privacy**
- Only syncs groups matching specified patterns
- User filtering prevents disabled accounts from syncing
- No sensitive data stored in OpenShift

## 🔍 Monitoring and Troubleshooting

### **Check Operator Status**
```bash
# Check if operator is running
oc get pods -n group-sync-operator

# Check operator logs
oc logs -n group-sync-operator -l app=group-sync-operator

# Check GroupSync status
oc get groupsync -n group-sync-operator
oc describe groupsync azure-ad-groupsync -n group-sync-operator
```

### **Check Synchronized Groups**
```bash
# List all groups
oc get groups

# Check specific group details
oc get group azure-openshift-admins -o yaml
oc get group azure-openshift-users -o yaml

# Check group members
oc get group azure-openshift-admins -o jsonpath='{.users}'
```

### **Common Issues**

1. **Authentication Failures**
   - Verify Azure AD credentials
   - Check application permissions
   - Verify tenant ID and client ID

2. **Groups Not Syncing**
   - Check group filter pattern
   - Verify groups exist in Azure AD
   - Check operator logs for errors

3. **Users Not Appearing**
   - Verify user filtering
   - Check if users are enabled in Azure AD
   - Verify group membership in Azure AD

## 📚 Integration with OAuth

### **Complementary Functionality**
- **OAuth**: Handles authentication and initial group claims
- **Group Sync Operator**: Provides ongoing group synchronization
- **Combined Effect**: Seamless user experience with automatic group updates

### **Workflow**
1. User authenticates via OAuth with Azure AD
2. Initial group membership is established from OAuth claims
3. Group Sync Operator continuously updates group membership
4. Changes in Azure AD are automatically reflected in OpenShift

## 🚀 Deployment

### **Via ArgoCD**
The component is automatically deployed when enabled in your cluster values:

```yaml
group-sync-operator:
  enabled: true
  labels:
    component: authentication
    phase: advanced
  source:
    path: components/group-sync-operator
  destination:
    namespace: group-sync-operator
```

### **Manual Deployment**
```bash
# Apply the configuration
oc apply -k kohler-openshift/components/group-sync-operator/

# Check deployment status
oc get pods -n group-sync-operator
oc get groupsync -n group-sync-operator
```

## 📋 Configuration Options

### **GroupSync Customization**
You can modify the `azure-ad-groupsync.yaml` to:

- **Change sync frequency**: Modify the `schedule` field
- **Adjust group filtering**: Modify the `groupFilter` field
- **Customize user filtering**: Modify the `userFilter` field
- **Enable/disable pruning**: Set `prune: true/false`

### **Azure AD Integration**
- **Multiple tenants**: Add additional providers
- **Different applications**: Use separate credentials for different purposes
- **Custom filters**: Implement specific business logic for group selection

## 🔮 Future Enhancements

### **Planned Features**
- **Vault Integration**: Store Azure AD credentials in Vault
- **Advanced Filtering**: More sophisticated group and user selection
- **Multi-Cloud Support**: Extend to other identity providers
- **Audit Logging**: Enhanced logging and monitoring capabilities

### **Customization Options**
- **Custom Group Mappings**: Map Azure AD groups to specific OpenShift groups
- **Role Assignment**: Automatically assign roles based on group membership
- **Namespace Provisioning**: Create namespaces for specific groups
- **Quota Management**: Set resource quotas based on group membership

---
*Generated on: 2025-08-15*
*Cluster: ocp2-mbh44*
*Environment: Production*
