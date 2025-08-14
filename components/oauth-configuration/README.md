# OpenShift OAuth Configuration

This component configures authentication for the OpenShift cluster with multiple identity providers.

## Current Configuration

### 1. HTPasswd Authentication (Primary - Active)
- **Purpose**: Provides immediate local access while Azure AD is configured
- **Default User**: `admin` / `Admin123!`
- **Security**: Change these credentials in production

### 2. Azure AD SSO (Secondary - Inactive)
- **Purpose**: Corporate single sign-on integration
- **Status**: Configured but requires valid client secret
- **Note**: Currently using placeholder secret

## Usage

### Immediate Access (HTPasswd)
Users can log in immediately using:
- **Username**: `admin`
- **Password**: `Admin123!`

### Adding More HTPasswd Users
1. Generate htpasswd entry:
   ```bash
   htpasswd -nb username password
   ```
2. Add to `htpasswd-users.yaml` file
3. Apply the updated configuration

### Enabling Azure AD
1. Update the Azure AD client secret in Azure portal
2. Update the secret in the cluster:
   ```bash
   oc create secret generic openid-client-secret-azuread \
     --from-literal=clientSecret="YOUR_REAL_SECRET" \
     -n openshift-config \
     --dry-run=client -o yaml | oc apply -f -
   ```
3. Restart OAuth server:
   ```bash
   oc rollout restart deployment/oauth-openshift -n openshift-authentication
   ```

## Security Notes

- **HTPasswd passwords are encrypted** but stored in Git
- **Change default credentials** before production use
- **Azure AD secrets** should never be committed to Git
- **Use external secrets** or sealed secrets for production

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

# Check secrets
oc get secret htpasswd-secret -n openshift-config
oc get secret openid-client-secret-azuread -n openshift-config
```
