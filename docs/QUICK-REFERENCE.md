# 🚀 Quick Reference: GitHub Secrets for Kohler OpenShift

## 📋 Essential Commands

### Initial Setup
```bash
# Clone and navigate to project
git clone https://github.com/kohler-co/kohler-openshift.git
cd kohler-openshift

# Login to OpenShift cluster
oc login --token=your-token --server=your-server

# Run automated setup
./scripts/setup-github-secrets.sh
```

### GitHub Actions Workflows

#### Trigger Secret Management Workflow
1. Go to **Actions** → **Secrets Management and Deployment**
2. Click **Run workflow**
3. Select environment: `dev` / `staging` / `prod`
4. Enable **Deploy secrets to cluster** if needed

#### Trigger Vault Integration
1. Go to **Actions** → **Vault Integration**
2. Click **Run workflow**
3. Select operation: `sync` / `backup` / `restore`

## 🔐 Required GitHub Secrets

### Repository Level (Settings → Secrets → Actions)
```bash
# OpenShift Access
OPENSHIFT_SERVER=https://api.ocp-dev.kohler.com:6443
OPENSHIFT_TOKEN=sha256~your-service-account-token

# Application Secrets
AZURE_AD_CLIENT_SECRET=your-azure-ad-client-secret
OADP_AWS_ACCESS_KEY_ID=your-aws-access-key
OADP_AWS_SECRET_ACCESS_KEY=your-aws-secret-key

# Registry Access
REGISTRY_USERNAME=your-quay-username
REGISTRY_PASSWORD=your-quay-password

# Sealed Secrets
KUBESEAL_CERT=-----BEGIN CERTIFICATE-----...-----END CERTIFICATE-----
```

### Vault Integration (Optional)
```bash
# Vault Configuration
VAULT_ADDR=https://vault.kohler.com
VAULT_TOKEN=hvs.your-vault-token
# OR
VAULT_ROLE_ID=your-approle-role-id
VAULT_SECRET_ID=your-approle-secret-id
```

## 🛠️ Common Operations

### Extract Existing Secrets
```bash
# Get Azure AD secret from cluster
oc get secret openid-client-secret-azuread -n openshift-config -o jsonpath='{.data.clientSecret}' | base64 -d

# Get OADP credentials from cluster
oc get secret cloud-credentials -n openshift-adp -o jsonpath='{.data.cloud}' | base64 -d

# Get service account token
oc whoami --show-token
```

### Manual Secret Deployment
```bash
# Create Azure AD secret manually
oc create secret generic openid-client-secret-azuread \
  --namespace=openshift-config \
  --from-literal=clientSecret="your-actual-secret"

# Create OADP backup credentials manually
cat > cloud-credentials.txt << EOF
[default]
aws_access_key_id=your-access-key
aws_secret_access_key=your-secret-key
EOF

oc create secret generic cloud-credentials \
  --namespace=openshift-adp \
  --from-file=cloud=cloud-credentials.txt

rm cloud-credentials.txt
```

### Generate Sealed Secrets
```bash
# Install kubeseal
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Get controller certificate
oc get secret -n sealed-secrets-system sealed-secrets-key -o jsonpath='{.data.tls\.crt}' | base64 -d > kubeseal-cert.pem

# Create sealed secret
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --dry-run=client -o yaml | \
kubeseal --cert kubeseal-cert.pem -o yaml > my-sealed-secret.yaml
```

## 🔧 Troubleshooting

### Workflow Failures
```bash
# Check workflow logs in GitHub Actions
# Common issues:
# 1. Missing secrets → Add to GitHub repository secrets
# 2. Invalid kubeseal cert → Re-extract from cluster
# 3. Cluster connection issues → Verify OPENSHIFT_SERVER and OPENSHIFT_TOKEN
```

### Secret Not Found in Cluster
```bash
# Check if secret exists
oc get secrets -n NAMESPACE

# Check External Secrets Operator status
oc get externalsecret -A
oc describe externalsecret SECRET_NAME -n NAMESPACE

# Check Sealed Secrets controller
oc get pods -n sealed-secrets-system
oc logs deployment/sealed-secrets-controller -n sealed-secrets-system
```

### Vault Connection Issues
```bash
# Test Vault connectivity
vault status -address=$VAULT_ADDR

# Test authentication
vault auth -method=token token=$VAULT_TOKEN

# Check External Secrets Operator logs
oc logs deployment/external-secrets -n external-secrets-system
```

## 📁 File Structure After Setup

```
kohler-openshift/
├── .github/
│   └── workflows/
│       ├── secrets-management.yml      # Main secrets workflow
│       └── vault-integration.yml       # Vault operations
├── components/
│   ├── external-secrets/               # External Secrets Operator config
│   ├── oauth-configuration/
│   │   ├── azure-ad-client-secret.yaml          # Template
│   │   └── azure-ad-client-sealed-secret.yaml   # Generated
│   └── oadp-configuration/
│       ├── backup-storage-credentials.yaml      # Template
│       └── backup-storage-sealed-secret.yaml    # Generated
├── docs/
│   ├── GITHUB-SECRETS-SETUP.md         # Detailed setup guide
│   └── SECRETS-MANAGEMENT.md           # Security best practices
├── scripts/
│   ├── setup-github-secrets.sh         # Linux/macOS setup script
│   └── setup-github-secrets.ps1        # Windows PowerShell script
└── extracted-secrets/                  # Generated (not in Git)
    ├── github-secrets.env              # Exported secrets
    └── kubeseal-cert.pem               # Controller certificate
```

## 🎯 Next Steps

1. **Set up environment-specific secrets**:
   - Go to Settings → Environments
   - Create: `dev`, `staging`, `prod`
   - Add environment-specific secret values

2. **Enable branch protection**:
   - Settings → Branches → Add rule
   - Require status checks
   - Require pull request reviews

3. **Configure monitoring**:
   - Review GitHub Actions workflow runs
   - Set up notifications for failures
   - Monitor secret rotation schedules

4. **Security review**:
   - Regular secret rotation
   - Access audit
   - Security scan results

## 📞 Support Contacts

- **DevOps Team**: For GitHub Actions and CI/CD
- **Platform Team**: For OpenShift cluster access
- **Security Team**: For Vault and secret management
- **Identity Team**: For Azure AD configuration

---

💡 **Pro Tip**: Bookmark this page and the [detailed setup guide](docs/GITHUB-SECRETS-SETUP.md) for easy reference!
