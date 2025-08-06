# HashiCorp Vault Community Edition Integration

This component deploys HashiCorp Vault Community Edition on OpenShift clusters with full integration to the External Secrets Operator for centralized secret management.

## Overview

The Vault deployment includes:
- **Secure Vault Server**: TLS-enabled Vault 1.15.2 with file storage backend
- **Automated Initialization**: Job that initializes Vault and stores unseal keys securely
- **Kubernetes Authentication**: Configured for External Secrets Operator integration
- **OpenShift Route**: Secure access to Vault UI
- **Persistent Storage**: Data persistence across pod restarts
- **RBAC Configuration**: Proper security contexts and service accounts

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ External Secrets│    │   Vault Server  │    │   Applications  │
│   Operator      │───▶│  (vault-system) │───▶│   (secrets)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │              ┌─────────────────┐              │
        └─────────────▶│  Kubernetes API │◀─────────────┘
                       │   (auth method) │
                       └─────────────────┘
```

## Components

### 1. Vault Server (`deployment.yaml`)
- **Image**: `hashicorp/vault:1.15.2`
- **Storage**: File storage backend with persistent volume
- **Security**: 
  - Non-root security context (UID 100, GID 1000)
  - Read-only root filesystem
  - TLS encryption for all communications
  - Resource limits and requests

### 2. Automated Initialization (`vault-unsealer-job.yaml`)
- Initializes Vault with 5 key shares (threshold: 3)
- Stores unseal keys in Kubernetes secrets
- Automatically unseals Vault after initialization
- Runs once on initial deployment

### 3. Kubernetes Authentication (`vault-config-job.yaml`)
- Configures Kubernetes auth method
- Creates policy for External Secrets Operator
- Sets up role mapping for service accounts
- Enables secret engines (KV v2)

### 4. External Secrets Integration (`../external-secrets/`)
- ClusterSecretStore for cluster-wide access
- SecretStore for namespace-specific access
- Example ExternalSecret configurations
- Kubernetes authentication using service account tokens

## Deployment

### Prerequisites
1. OpenShift GitOps (ArgoCD) installed
2. External Secrets Operator deployed
3. TLS certificates for Vault (auto-generated if not provided)

### Installation
```bash
# Apply the Vault applications
oc apply -f argocd-apps/vault-apps.yaml

# Monitor deployment
oc get applications -n openshift-gitops vault-community external-secrets-vault
oc get pods -n vault-system
oc get pods -n external-secrets-system
```

### Access Vault UI
```bash
# Get the Vault route
VAULT_URL=$(oc get route vault-ui -n vault-system -o jsonpath='{.spec.host}')
echo "Vault UI: https://$VAULT_URL"

# Get root token (for initial setup only)
oc get secret vault-init -n vault-system -o jsonpath='{.data.root-token}' | base64 -d
```

## Configuration

### Environment-Specific Settings
The deployment uses Kustomize patches for environment-specific configuration:

- **Route hostname**: `vault-${CLUSTER_NAME}.apps.${CLUSTER_DOMAIN}`
- **API address**: Configured for external access
- **Cluster address**: Internal service communication
- **Storage path**: `/vault/data` on persistent volume

### Security Policies
Vault is configured with the following security policies:

1. **External Secrets Policy**: Read access to secret paths
2. **Admin Policy**: Full access for administrative tasks
3. **Application Policies**: Scoped access for specific applications

### Secret Engines
- **KV v2**: Key-value secret storage at `secret/`
- **Kubernetes Auth**: Service account token validation
- **Transit**: Encryption as a service (future enhancement)

## Usage Examples

### 1. Store Secrets in Vault
```bash
# Set environment
export VAULT_ADDR="https://vault-dr.apps.your-cluster.com"
export VAULT_TOKEN="your-root-token"

# Store application secrets
vault kv put secret/applications/my-app \
  database_url="postgresql://db.example.com:5432/myapp" \
  database_username="myapp_user" \
  database_password="secure_password" \
  api_key="your-api-key"

# Store TLS certificates
vault kv put secret/certificates/my-app \
  tls_cert="-----BEGIN CERTIFICATE-----..." \
  tls_key="-----BEGIN PRIVATE KEY-----..."
```

### 2. Create ExternalSecret
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
  namespace: my-namespace
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-secret-store
    kind: ClusterSecretStore
  target:
    name: my-app-secrets
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: applications/my-app
        property: database_url
    - secretKey: database-username
      remoteRef:
        key: applications/my-app
        property: database_username
    - secretKey: database-password
      remoteRef:
        key: applications/my-app
        property: database_password
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
              name: my-app-secrets
              key: database-url
        - name: DATABASE_USERNAME
          valueFrom:
            secretKeyRef:
              name: my-app-secrets
              key: database-username
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-app-secrets
              key: database-password
```

## Troubleshooting

### Common Issues

1. **Vault Pod Not Starting**
   ```bash
   oc logs deployment/vault -n vault-system
   oc describe pod -l app=vault -n vault-system
   ```

2. **Initialization Job Failed**
   ```bash
   oc logs job/vault-unsealer -n vault-system
   oc get events -n vault-system --sort-by='.lastTimestamp'
   ```

3. **External Secrets Cannot Connect**
   ```bash
   oc logs deployment/external-secrets-operator -n external-secrets-system
   oc describe clustersecretstore vault-secret-store
   ```

4. **Authentication Issues**
   ```bash
   # Check Kubernetes auth configuration
   vault auth list
   vault read auth/kubernetes/config
   
   # Verify service account token
   oc get serviceaccount external-secrets-operator -n external-secrets-system -o yaml
   ```

### Health Checks
```bash
# Check Vault status
oc exec -it deployment/vault -n vault-system -- vault status

# Verify External Secrets status
oc get clustersecretstore vault-secret-store -o yaml

# Test secret synchronization
oc get externalsecret -A
oc describe externalsecret vault-example-secret
```

## Security Considerations

1. **Root Token**: Secure the root token and use it only for initial setup
2. **Unseal Keys**: Store unseal keys securely and consider using auto-unseal
3. **Network Policies**: Implement network policies to restrict Vault access
4. **Audit Logging**: Enable Vault audit logging for compliance
5. **Backup Strategy**: Regular backups of Vault data and configuration

## Monitoring and Alerting

The deployment includes:
- **Health Checks**: Liveness and readiness probes
- **Metrics**: Prometheus metrics endpoint (port 8220)
- **Logs**: Structured JSON logging
- **Events**: Kubernetes events for troubleshooting

## Backup and Recovery

1. **Data Backup**: Persistent volume snapshots
2. **Configuration Backup**: Export Vault policies and auth methods
3. **Disaster Recovery**: Automated restoration procedures

## Integration with Other Components

- **OADP**: Backup secrets stored in Vault
- **Cert-Manager**: Certificate storage and rotation
- **GitOps**: Secret synchronization with ArgoCD
- **Monitoring**: Integration with Prometheus and Grafana

## Future Enhancements

1. **Auto-Unseal**: Transit seal or cloud KMS integration
2. **High Availability**: Multi-replica Vault deployment
3. **Database Backend**: PostgreSQL or Consul storage
4. **Disaster Recovery**: Cross-cluster replication
5. **Policy as Code**: Terraform or Vault policy management

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review OpenShift and Vault documentation
3. Check ArgoCD application sync status
4. Examine pod logs and events
