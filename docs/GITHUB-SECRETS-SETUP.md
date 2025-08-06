# GitHub Secrets Configuration for Kohler OpenShift

This document outlines the setup and configuration of GitHub Secrets for the kohler-openshift project, implementing secure secret management using GitHub Actions, HashiCorp Vault, and Sealed Secrets.

## 🎯 Overview

The kohler-openshift project requires secure management of sensitive credentials including:
- Azure AD OAuth client secrets
- OADP backup storage credentials (AWS S3)
- Container registry credentials
- TLS certificates and keys
- Database passwords and connection strings

## 🔐 Required GitHub Secrets

### Core Infrastructure Secrets

| Secret Name | Description | Environment | Required |
|------------|-------------|-------------|----------|
| `OPENSHIFT_SERVER` | OpenShift cluster API server URL | All | ✅ |
| `OPENSHIFT_TOKEN` | Service account token for cluster access | All | ✅ |
| `AZURE_AD_CLIENT_SECRET` | Azure AD OAuth application client secret | All | ✅ |
| `OADP_AWS_ACCESS_KEY_ID` | AWS access key for OADP backups | All | ✅ |
| `OADP_AWS_SECRET_ACCESS_KEY` | AWS secret key for OADP backups | All | ✅ |

### Vault Integration Secrets

| Secret Name | Description | Environment | Required |
|------------|-------------|-------------|----------|
| `VAULT_ADDR` | HashiCorp Vault server URL | All | ✅ |
| `VAULT_TOKEN` | Vault authentication token | All | ⚠️* |
| `VAULT_ROLE_ID` | Vault AppRole role ID | All | ⚠️* |
| `VAULT_SECRET_ID` | Vault AppRole secret ID | All | ⚠️* |
| `VAULT_NAMESPACE` | Vault namespace (for Vault Enterprise) | All | ❌ |

*Either `VAULT_TOKEN` OR both `VAULT_ROLE_ID` and `VAULT_SECRET_ID` are required.

### Registry and Build Secrets

| Secret Name | Description | Environment | Required |
|------------|-------------|-------------|----------|
| `REGISTRY_USERNAME` | Container registry username | All | ✅ |
| `REGISTRY_PASSWORD` | Container registry password/token | All | ✅ |

### Sealed Secrets

| Secret Name | Description | Environment | Required |
|------------|-------------|-------------|----------|
| `KUBESEAL_CERT` | Sealed Secrets controller public certificate | All | ✅ |

## 🚀 Setup Instructions

### 1. Setting Up GitHub Repository Secrets

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add each required secret

#### For Development Environment:
```bash
# OpenShift Cluster Access
OPENSHIFT_SERVER: https://api.ocp-dev.kohler.com:6443
OPENSHIFT_TOKEN: sha256~your-service-account-token

# Azure AD Integration
AZURE_AD_CLIENT_SECRET: your-azure-ad-client-secret

# OADP Backup Credentials
OADP_AWS_ACCESS_KEY_ID: your-aws-access-key
OADP_AWS_SECRET_ACCESS_KEY: your-aws-secret-key

# Container Registry
REGISTRY_USERNAME: your-quay-username
REGISTRY_PASSWORD: your-quay-password
```

#### For Production Environment:
Create environment-specific secrets by:
1. Go to **Settings** → **Environments**
2. Create environments: `dev`, `staging`, `prod`
3. Add environment-specific secrets with the same names but different values

### 2. Setting Up HashiCorp Vault Integration

#### Option A: Using Vault Token Authentication
```bash
# Vault Configuration
VAULT_ADDR: https://vault.kohler.com
VAULT_TOKEN: hvs.your-vault-token
```

#### Option B: Using AppRole Authentication (Recommended for Production)
```bash
# Vault Configuration
VAULT_ADDR: https://vault.kohler.com
VAULT_ROLE_ID: your-approle-role-id
VAULT_SECRET_ID: your-approle-secret-id
```

### 3. Setting Up Sealed Secrets

1. **Get the Sealed Secrets Controller Certificate:**
```bash
# Connect to your OpenShift cluster
oc login --token=your-token --server=your-server

# Get the public certificate
oc get secret -n sealed-secrets-system sealed-secrets-key -o jsonpath='{.data.tls\.crt}' | base64 -d > kubeseal-cert.pem

# Copy the certificate content to GitHub Secret KUBESEAL_CERT
cat kubeseal-cert.pem
```

2. **Add the certificate as a GitHub Secret:**
   - Name: `KUBESEAL_CERT`
   - Value: The entire content of `kubeseal-cert.pem`

## 📋 Workflow Usage

### Automatic Secret Management

The workflows automatically trigger on:
- **Push to main branch**: Updates sealed secrets and deploys to production
- **Push to develop branch**: Updates sealed secrets for development
- **Pull requests**: Validates secret templates and checks for plaintext secrets

### Manual Secret Operations

#### Deploy Secrets to Specific Environment
```bash
# Go to Actions → Secrets Management and Deployment → Run workflow
# Select environment: dev/staging/prod
# Enable: Deploy secrets to cluster
```

#### Sync Secrets to Vault
```bash
# Go to Actions → Vault Integration → Run workflow
# Select environment: dev/staging/prod
# Select operation: sync
```

#### Backup Vault Secrets
```bash
# Go to Actions → Vault Integration → Run workflow
# Select environment: dev/staging/prod
# Select operation: backup
```

## 🛡️ Security Features

### 1. Automated Security Scanning
- **Trivy vulnerability scanning** on every push
- **Secret detection** to prevent plaintext secrets in code
- **YAML validation** for all Kubernetes manifests

### 2. Multi-Layer Secret Protection
- **GitHub Secrets**: Environment-specific secret storage
- **Sealed Secrets**: Encrypted secrets safe for Git storage
- **HashiCorp Vault**: Enterprise-grade secret management
- **External Secrets Operator**: Automated secret synchronization

### 3. Access Controls
- **Environment protection rules**: Require approvals for production deployments
- **Branch protection**: Prevent direct pushes to main branch
- **Service account tokens**: Least-privilege cluster access

## 📁 Secret File Structure

After setup, your project will have the following secret management structure:

```
kohler-openshift/
├── .github/
│   └── workflows/
│       ├── secrets-management.yml
│       └── vault-integration.yml
├── components/
│   ├── oauth-configuration/
│   │   ├── azure-ad-client-secret.yaml          # Template with placeholders
│   │   └── azure-ad-client-sealed-secret.yaml   # Generated sealed secret
│   ├── oadp-configuration/
│   │   ├── backup-storage-credentials.yaml      # Template with placeholders
│   │   └── backup-storage-sealed-secret.yaml    # Generated sealed secret
│   └── registry-configuration/
│       └── registry-sealed-secret.yaml          # Generated sealed secret
└── docs/
    ├── GITHUB-SECRETS-SETUP.md                  # This document
    └── SECRETS-MANAGEMENT.md                     # Existing secret management guide
```

## 🔧 Troubleshooting

### Common Issues

#### 1. "Secret not found" errors
```bash
# Check if secret exists in GitHub
# Go to Settings → Secrets and variables → Actions

# Verify secret deployment in cluster
oc get secrets -n openshift-config
oc get secrets -n openshift-adp
```

#### 2. Sealed Secrets not decrypting
```bash
# Check if Sealed Secrets controller is running
oc get pods -n sealed-secrets-system

# Verify certificate matches
oc get secret -n sealed-secrets-system sealed-secrets-key -o jsonpath='{.data.tls\.crt}' | base64 -d
```

#### 3. Vault authentication failures
```bash
# Test Vault connectivity
vault status -address=$VAULT_ADDR

# Test authentication
vault auth -method=token token=$VAULT_TOKEN
# OR
vault write auth/approle/login role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID
```

#### 4. External Secrets Operator issues
```bash
# Check External Secrets Operator status
oc get pods -n external-secrets-system

# Check SecretStore status
oc get secretstore -A

# Check ExternalSecret status
oc get externalsecret -A
oc describe externalsecret azure-ad-client-secret -n openshift-config
```

## 📞 Support

For issues with:
- **GitHub Actions**: Contact DevOps team
- **OpenShift cluster access**: Contact Platform team
- **Vault integration**: Contact Security team
- **Azure AD configuration**: Contact Identity team

## 🔄 Maintenance

### Regular Tasks
1. **Monthly**: Rotate service account tokens
2. **Quarterly**: Rotate Azure AD client secrets
3. **Annually**: Rotate AWS backup credentials
4. **As needed**: Update Sealed Secrets controller certificate

### Monitoring
- Monitor GitHub Actions workflow runs
- Check External Secrets Operator logs
- Verify secret synchronization status
- Review security scan results
