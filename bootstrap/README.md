# Bootstrap Deployment Guide

This directory contains ArgoCD Application manifests for deploying the complete cluster infrastructure using GitOps principles.

## Overview

The bootstrap process uses the "App of Apps" pattern to deploy infrastructure components in the correct order using ArgoCD sync waves.

## Deployment Order

### Phase 1: Core Infrastructure (Sync Waves 1-5)
- **core-applications.yaml**: AppProject, gitops-operator, network/node configuration, gitops-configuration

### Phase 2: Operators (Sync Waves 6-10)  
- **operators-applications.yaml**: ODF operator, OADP operator, cert-manager, vSphere configuration

### Phase 3: Infrastructure Services (Sync Waves 11-14)
- **infrastructure-applications.yaml**: Image registry, RBAC, security policies, OAuth

### Phase 4: Data Services Configuration (Sync Waves 15-25)
- **configuration-applications.yaml**: ODF configuration, OADP configuration, scheduled backups

## Deployment Steps

### 1. Initial Bootstrap
Apply the master bootstrap application (App of Apps):
```bash
oc apply -f app-of-apps.yaml
```

This will automatically deploy all other applications in the correct order.

### 2. Monitor Deployment
Watch the ArgoCD UI or use CLI:
```bash
# Check all applications
argocd app list

# Watch specific application
argocd app sync bootstrap-cluster-config --watch

# Check sync status
argocd app get bootstrap-cluster-config
```

### 3. Verify Components
Run the verification script after deployment:
```bash
../scripts/verify-deployment.sh
```

## Sync Wave Strategy

| Wave | Purpose | Components |
|------|---------|------------|
| 0 | Bootstrap | App of Apps |
| 1 | AppProject | cluster-config project |
| 2 | Core GitOps | GitOps operator |
| 3 | Network/Node | Basic cluster config |
| 4 | GitOps Config | ArgoCD configuration |
| 6 | Operators | ODF, OADP, cert-manager |
| 8 | Platform | vSphere integration |
| 11 | Registry | Image registry config |
| 12 | Security | RBAC, policies |
| 13 | Authentication | OAuth/SSO |
| 15 | Storage | ODF configuration |
| 15 | Backup | OADP configuration |
| 25 | Automation | Scheduled backups |

## Troubleshooting

### Common Issues
1. **Sync Failures**: Check resource dependencies and namespace creation
2. **Permission Errors**: Verify ArgoCD has necessary RBAC permissions
3. **Operator Installation**: Wait for operators to be fully ready before configurations

### Recovery
```bash
# Refresh applications
argocd app sync bootstrap-cluster-config

# Hard refresh with server-side apply
argocd app sync bootstrap-cluster-config --force

# Delete and recreate
oc delete -f app-of-apps.yaml
oc apply -f app-of-apps.yaml
```

## Customization

To customize for different clusters:
1. Update `clusters/dev/values.yaml` for cluster-specific settings
2. Modify ArgoCD Applications to point to different value files
3. Adjust sync waves if dependencies change

## Production Deployment

For production deployment:
1. Create `clusters/prd/values.yaml` with production settings
2. Update Application manifests to use production value files
3. Test on dev cluster first
4. Apply same bootstrap process to production cluster
