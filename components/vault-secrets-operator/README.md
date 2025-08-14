# Vault Secrets Operator (VSO)

This component deploys the Vault Secrets Operator on OpenShift clusters to provide Kubernetes-native secret management using HashiCorp Vault as the backend.

## Overview

The Vault Secrets Operator (VSO) provides:
- **Kubernetes-Native Secrets**: Manage secrets using Kubernetes CRDs
- **Vault Integration**: Seamless integration with HashiCorp Vault
- **Automatic Synchronization**: Real-time secret updates from Vault
- **RBAC Integration**: Kubernetes role-based access control
- **Multi-Namespace Support**: Cluster-wide and namespace-scoped secrets

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │    │ Vault Secrets   │    │   HashiCorp     │
│   (Pods/Jobs)   │───▶│   Operator      │───▶│     Vault       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │              ┌─────────────────┐              │
        └─────────────▶│  Kubernetes API │◀─────────────┘
                       │   (Secrets)     │
                       └─────────────────┘
```

## Components

### 1. Operator Deployment (`subscription.yaml`)
- **Source**: Red Hat Operators
- **Channel**: Stable
- **Installation**: Automatic approval
- **Namespace**: `vault-secrets-system`

### 2. Vault Authentication (`secret-store.yaml`)
- **Method**: Kubernetes service account authentication
- **Role**: `vault-secrets-operator`
- **Policy**: Read access to secret paths
- **TTL**: 1 hour token lifetime

### 3. Example Secret (`secret-store.yaml`)
- **Type**: KV v2 secret engine
- **Path**: `secret/example`
- **Refresh**: Every 15 seconds
- **Namespace**: `vault-secrets-system`

## Deployment

### Prerequisites
1. OpenShift GitOps (ArgoCD) installed
2. HashiCorp Vault deployed and configured
3. Kubernetes authentication enabled in Vault
4. Proper RBAC permissions

### Installation
```bash
# Apply the VSO applications
oc apply -f argocd-apps/vault-apps.yaml

# Monitor deployment
oc get applications -n openshift-gitops vault-secrets-operator
oc get pods -n vault-secrets-system
oc get vaultauth -n vault-secrets-system
oc get vaultstaticsecret -n vault-secrets-system
```

## Configuration

### Vault Authentication
The operator uses Kubernetes service account authentication to connect to Vault:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: kubernetes
spec:
  method: kubernetes
  kubernetes:
    role: vault-secrets-operator
    serviceAccount:
      name: vault-secrets-operator
      namespace: vault-secrets-system
    mountPath: /v1/auth/kubernetes
```

### Vault Policies
Vault must have the following policy for the operator:

```hcl
# Vault Secrets Operator policy
path "secret/data/*" {
  capabilities = ["read"]
}
path "secret/metadata/*" {
  capabilities = ["read"]
}
path "auth/kubernetes/login" {
  capabilities = ["create", "read"]
}
```

### Vault Role
Vault must have the following role configured:

```hcl
vault write auth/kubernetes/role/vault-secrets-operator \
  bound_service_account_names=vault-secrets-operator \
  bound_service_account_namespaces=vault-secrets-system \
  policies=vault-secrets-operator \
  ttl=1h
```

## Usage Examples

### 1. Create a Vault Static Secret
```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: database-credentials
  namespace: my-app
spec:
  type: kv-v2
  mount: secret
  path: databases/myapp
  refreshAfter: 30s
  secretName: database-credentials
  hvs:
    vaultAuthRef: kubernetes
```

### 2. Use Secrets in Applications
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
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: host
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: password
```

### 3. Create a Vault Dynamic Secret
```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: database-credentials
  namespace: my-app
spec:
  mount: database
  path: myapp
  type: database
  secretName: database-credentials
  hvs:
    vaultAuthRef: kubernetes
  options:
    role: myapp
```

## Troubleshooting

### Common Issues

1. **Operator Not Starting**
   ```bash
   oc get pods -n vault-secrets-system
   oc logs deployment/vault-secrets-operator -n vault-secrets-system
   oc describe pod -l app.kubernetes.io/name=vault-secrets-operator -n vault-secrets-system
   ```

2. **Authentication Failures**
   ```bash
   # Check Vault auth configuration
   oc get vaultauth kubernetes -n vault-secrets-system -o yaml
   
   # Check Vault operator logs
   oc logs deployment/vault-secrets-operator -n vault-secrets-system
   ```

3. **Secret Synchronization Issues**
   ```bash
   # Check secret status
   oc get vaultstaticsecret -n vault-secrets-system
   oc describe vaultstaticsecret example-secret -n vault-secrets-system
   
   # Check events
   oc get events -n vault-secrets-system --sort-by='.lastTimestamp'
   ```

### Health Checks
```bash
# Check operator status
oc get deployment vault-secrets-operator -n vault-secrets-system

# Check custom resources
oc get vaultauth -n vault-secrets-system
oc get vaultstaticsecret -n vault-secrets-system
oc get vaultdynamicsecret -n vault-secrets-system

# Check secrets
oc get secret -n vault-secrets-system
```

## Security Considerations

1. **Service Account Permissions**: Minimal required permissions
2. **Vault Policies**: Least-privilege access to secrets
3. **Token Rotation**: Regular rotation of service account tokens
4. **Network Policies**: Restrict access to Vault Secrets Operator
5. **Audit Logging**: Monitor secret access and changes

## Monitoring and Alerting

The operator provides:
- **Health Checks**: Pod health and readiness
- **Metrics**: Prometheus metrics for monitoring
- **Logs**: Detailed logging for troubleshooting
- **Events**: Kubernetes events for secret changes

## Integration with Other Components

- **HashiCorp Vault**: Backend secret storage
- **OpenShift GitOps**: GitOps-based deployment
- **Monitoring Stack**: Prometheus and Grafana integration
- **Security Policies**: Network policies and RBAC

## Best Practices

1. **Namespace Isolation**: Use separate namespaces for different applications
2. **Secret Naming**: Consistent naming convention for secrets
3. **Refresh Intervals**: Appropriate refresh intervals based on security requirements
4. **Error Handling**: Implement proper error handling for secret access
5. **Backup Strategy**: Regular backup of Vault data and operator configuration

## Future Enhancements

1. **Multi-Vault Support**: Connect to multiple Vault instances
2. **Secret Rotation**: Automatic secret rotation capabilities
3. **Policy as Code**: GitOps-based policy management
4. **Advanced Auth Methods**: Support for additional authentication methods
5. **Cross-Cluster Replication**: Multi-cluster secret synchronization
