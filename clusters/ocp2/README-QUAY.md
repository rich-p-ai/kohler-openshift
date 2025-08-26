# Quay Registry Deployment for OCP2 Cluster

This directory contains cluster-specific configuration for deploying Red Hat Quay Registry to the ocp2 cluster.

## 🏗️ Architecture Overview

The Quay deployment on ocp2 consists of:

### 1. **Core Components** (Sync Wave 5)
- **Quay Operator**: Red Hat Quay operator installation
- **Namespace**: `quay-enterprise` namespace with monitoring enabled

### 2. **Infrastructure** (Sync Wave 15)  
- **High-Availability PostgreSQL**: 3-replica StatefulSet with ODF storage
- **High-Availability Redis**: 3-replica StatefulSet with ODF storage
- **ODF S3 Storage**: ObjectBucketClaim for container image storage
- **Azure AD Integration**: OIDC configuration with team synchronization

### 3. **Registry Configuration** (Sync Wave 20)
- **QuayRegistry CR**: Main Quay registry configuration
- **Route**: External access via `quay.apps.ocp2.kohlerco.com`

### 4. **Multi-Cluster Mirroring** (Sync Wave 25)
- **Cross-cluster RBAC**: Service accounts and permissions
- **Mirror Configuration**: Repository mirroring to ocp-prd, ocp-dr, and ocp4

## 🚀 Deployment

### Prerequisites
1. **ODF Storage**: Ensure OpenShift Data Foundation is deployed and operational
2. **ArgoCD**: OpenShift GitOps must be installed and configured
3. **Cluster Access**: cluster-admin permissions on ocp2
4. **Azure AD Configuration**: Configure Azure AD credentials before deployment

### Configure Azure AD Credentials
Before deploying, you must configure the Azure AD credentials:

```bash
# Option 1: Set environment variables
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id" 
export AZURE_CLIENT_SECRET="your-client-secret"

# Option 2: Update the configuration files directly
# Edit components/quay-configuration/azure-ad-config.yaml
# Edit components/quay-configuration/quay-registry.yaml
# Edit clusters/ocp2/quay-values.yaml
```

### Deploy Quay Registry
Apply the ArgoCD applications:
```bash
# Deploy all Quay components to ocp2
oc apply -f argocd-apps/quay-ocp2.yaml

# Monitor deployment progress
oc get applications -n openshift-gitops | grep quay

# Check component status
oc get pods -n quay-enterprise
oc get quayregistry -n quay-enterprise
```

### Verify Deployment
```bash
# Check Quay operator status
oc get csv -n openshift-operators | grep quay

# Verify Quay registry status
oc get quayregistry kohler-quay-registry -n quay-enterprise -o yaml

# Check database and redis
oc get statefulsets -n quay-enterprise
oc get pvc -n quay-enterprise

# Verify ODF storage
oc get objectbucketclaim -n quay-enterprise
```

## 🔐 Access Configuration

### Registry Access
- **URL**: https://quay.apps.ocp2.kohlerco.com
- **Authentication**: Azure AD OIDC
- **Admin User**: `admin` (configured as superuser)

### Azure AD Groups
- **quay-admins**: Full administrative access
- **quay-developers**: Repository creation and management
- **quay-readers**: Read-only access to repositories

## 📊 Monitoring

Quay includes built-in monitoring that integrates with OpenShift monitoring:
- **Metrics**: Available in OpenShift Console monitoring
- **Alerts**: Configured for high-availability components
- **Dashboards**: Quay-specific Grafana dashboards

## 🔄 Multi-Cluster Mirroring

Repository mirroring is configured for:
- **ocp-prd**: Production cluster (1-hour sync)
- **ocp-dr**: Disaster recovery (30-minute sync)  
- **ocp4**: Legacy cluster (2-hour sync)

Critical application repositories sync every 15 minutes.

## 🛠️ Troubleshooting

### Common Issues

**1. PostgreSQL Connection Issues**
```bash
# Check PostgreSQL pod status
oc get pods -n quay-enterprise | grep postgres

# Check PostgreSQL logs
oc logs -f statefulset/quay-postgres -n quay-enterprise
```

**2. ODF Storage Issues**
```bash
# Check ObjectBucketClaim status
oc get obc -n quay-enterprise

# Verify S3 credentials
oc get secret quay-registry-storage -n quay-enterprise -o yaml
```

**3. Azure AD Authentication Issues**
```bash
# Check OIDC configuration
oc get secret quay-config-bundle -n quay-enterprise -o yaml

# Verify Azure AD secret
oc get secret quay-azure-oidc-config -n quay-enterprise
```

### Support Information
- **Documentation**: [Red Hat Quay Documentation](https://docs.redhat.com/en/documentation/red_hat_quay)
- **Support**: Contact Kohler IT Infrastructure team
- **Repository**: https://github.com/rich-p-ai/kohler-openshift
