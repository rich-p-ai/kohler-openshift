# HashiCorp Vault Deployment

This component deploys HashiCorp Vault on OpenShift clusters with automated initialization, unsealing, and configuration.

## Overview

The Vault deployment includes:
- **Secure Vault Server**: TLS-enabled Vault 1.15.2 with file storage backend
- **Automated Initialization**: Job that initializes Vault and stores unseal keys securely
- **Automated Unsealing**: Job that unseals Vault using stored keys
- **Kubernetes Authentication**: Configured for Vault Secrets Operator integration
- **OpenShift Route**: Secure access to Vault UI
- **Persistent Storage**: Data persistence across pod restarts
- **RBAC Configuration**: Proper security contexts and service accounts

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Vault Secrets   │    │   Vault Server  │    │   Applications  │
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
  - Resource limits and requests

### 2. Automated Initialization (`init-job.yaml`)
- Initializes Vault with 5 key shares (threshold: 3)
- Stores unseal keys in Kubernetes secrets
- Runs once on initial deployment

### 3. Automated Unsealing (`unseal-job.yaml`)
- Retrieves unseal keys from Kubernetes secrets
- Automatically unseals Vault after initialization
- Runs after initialization is complete

### 4. Vault Configuration (`config-job.yaml`)
- Configures Kubernetes auth method
- Creates policy for Vault Secrets Operator
- Sets up role mapping for service accounts
- Enables secret engines (KV v2)

## Deployment

### Prerequisites
1. OpenShift GitOps (ArgoCD) installed
2. ODF storage available (for persistent volumes)
3. Proper RBAC permissions

### Installation
```bash
# Apply the Vault applications
oc apply -f argocd-apps/vault-apps.yaml

# Monitor deployment
oc get applications -n openshift-gitops vault-deployment vault-secrets-operator
oc get pods -n vault-system
oc get pods -n vault-secrets-system
```

### Access Vault UI
```bash
# Get the Vault route
VAULT_URL=$(oc get route vault-ui -n vault-system -o jsonpath='{.spec.host}')
echo "Vault UI: https://$VAULT_URL"

# Get root token (for initial setup only)
oc get secret vault-root-token -n vault-system -o jsonpath='{.data.root-token}' | base64 -d
```

## Configuration

### Environment-Specific Settings
The deployment uses Kustomize for environment-specific configuration:

- **Route hostname**: `vault-ui-vault-system.apps.ocp2.kohlerco.com`
- **API address**: Configured for external access
- **Cluster address**: Internal service communication
- **Storage path**: `/vault/data` on persistent volume

### Security Policies
Vault is configured with the following security policies:

1. **Vault Secrets Operator Policy**: Read access to secret paths
2. **Admin Policy**: Full access for administrative tasks
3. **Application Policies**: Scoped access for specific applications

### Secret Engines
- **KV v2**: Key-value secret storage at `secret/`
- **Kubernetes Auth**: Service account token validation

## Usage Examples

### 1. Store Secrets in Vault
```bash
# Set environment
export VAULT_ADDR="https://vault-ui-vault-system.apps.ocp2.kohlerco.com"
export VAULT_TOKEN="your-root-token"

# Store application secrets
vault kv put secret/applications/my-app \
  database_url="postgresql://db.example.com:5432/myapp" \
  database_username="myapp_user" \
  database_password="secure_password" \
  api_key="your-api-key"
```

### 2. Use Vault Secrets Operator
```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: my-app-secrets
  namespace: my-namespace
spec:
  type: kv-v2
  mount: secret
  path: applications/my-app
  refreshAfter: 15s
  secretName: my-app-secrets
  hvs:
    vaultAuthRef: kubernetes
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
   oc logs job/vault-init -n vault-system
   oc get events -n vault-system --sort-by='.lastTimestamp'
   ```

3. **Unsealing Job Failed**
   ```bash
   oc logs job/vault-unseal -n vault-system
   oc get secret vault-unseal-keys -n vault-system
   ```

4. **Configuration Job Failed**
   ```bash
   oc logs job/vault-config -n vault-system
   oc get secret vault-root-token -n vault-system
   ```

### Health Checks
```bash
# Check Vault status
oc exec -it deployment/vault -n vault-system -- vault status

# Verify secrets
oc get secret vault-unseal-keys -n vault-system
oc get secret vault-root-token -n vault-system

# Check jobs
oc get jobs -n vault-system
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
- **Logs**: Structured JSON logging
- **Events**: Kubernetes events for troubleshooting

## Integration with Other Components

- **Vault Secrets Operator**: For Kubernetes-native secret management
- **OADP**: Backup secrets stored in Vault
- **GitOps**: Secret synchronization with ArgoCD
- **Monitoring**: Integration with Prometheus and Grafana

## Future Enhancements

1. **Auto-Unseal**: Transit seal or cloud KMS integration
2. **High Availability**: Multi-replica Vault deployment
3. **Database Backend**: PostgreSQL or Consul storage
4. **Disaster Recovery**: Cross-cluster replication
5. **Policy as Code**: Terraform or Vault policy management
