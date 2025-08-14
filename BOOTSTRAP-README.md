# Bootstrap Deployment Scripts

This directory contains scripts to deploy the OpenShift GitOps bootstrap configuration from the `.bootstrap` folder.

## Files

- `deploy-bootstrap.sh` - Full-featured deployment script with error handling, waiting, and various options
- `deploy-bootstrap-simple.sh` - Simple script that applies all YAML files in order
- `.bootstrap/` - Directory containing the bootstrap YAML files

## Bootstrap Files Order

The bootstrap files are applied in the following order:

1. `0.namespace.yaml` - Creates the openshift-gitops-operator namespace
2. `1.operatorgroup.*.yaml` - Creates OperatorGroup resources
3. `2.subscription.yaml` - Installs the OpenShift GitOps operator
4. `3.cluster-rolebinding.yaml` - Creates necessary cluster role bindings
5. `4.argocd.yaml` - Deploys the ArgoCD instance
6. `5.repository-secret.yaml` - Configures repository access secrets
7. `6.root-application.yaml` - Creates the root ApplicationSet

## Prerequisites

1. OpenShift CLI (`oc`) must be installed and available in PATH
2. You must be logged into an OpenShift cluster with sufficient permissions
3. The cluster must have access to the Red Hat Operators catalog

## Usage

### Full-featured Script (Recommended)

```bash
# Basic deployment
./deploy-bootstrap.sh

# Dry run to see what would be deployed
./deploy-bootstrap.sh --dry-run

# Verbose output for troubleshooting
./deploy-bootstrap.sh --verbose

# Custom timeout (default is 300 seconds)
./deploy-bootstrap.sh --timeout 600

# Help
./deploy-bootstrap.sh --help
```

### Simple Script

```bash
# Deploy all bootstrap files
./deploy-bootstrap-simple.sh
```

## Features of the Full Script

- **Prerequisites Check**: Verifies `oc` is available and you're logged in
- **Ordered Deployment**: Applies files in the correct sequence
- **Resource Waiting**: Waits for resources to be ready before proceeding
- **Error Handling**: Stops on errors and provides clear error messages
- **Dry Run Mode**: Preview what would be deployed without making changes
- **Verbose Mode**: Detailed output for troubleshooting
- **Colored Output**: Easy to read status messages
- **Verification**: Checks deployment status after completion

## What Gets Deployed

This bootstrap process will:

1. Install the OpenShift GitOps operator
2. Create an ArgoCD instance in the `openshift-gitops` namespace
3. Configure repository access for GitOps
4. Deploy the root ApplicationSet that manages other applications
5. Set up the necessary RBAC permissions

## After Deployment

Once the bootstrap is complete:

1. ArgoCD UI will be available at the route shown in the script output
2. You can monitor applications with: `oc get applications -n openshift-gitops`
3. Check ArgoCD pods with: `oc get pods -n openshift-gitops`
4. Access ArgoCD with your OpenShift credentials (if RBAC is configured properly)

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure you have cluster-admin privileges
2. **Operator Installation Fails**: Check if the Red Hat Operators catalog is available
3. **ArgoCD Not Starting**: Check pod logs in the openshift-gitops namespace
4. **Repository Access Issues**: Verify the repository secret is correctly configured

### Debugging Commands

```bash
# Check operator installation
oc get csv -n openshift-gitops-operator

# Check ArgoCD status
oc get argocd -n openshift-gitops

# Check pods
oc get pods -n openshift-gitops

# Check ApplicationSet
oc get applicationset -n openshift-gitops

# View ArgoCD logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=argocd-server
```

## Manual Cleanup (if needed)

If you need to remove the bootstrap deployment:

```bash
# Remove in reverse order
oc delete -f .bootstrap/6.root-application.yaml
oc delete -f .bootstrap/5.repository-secret.yaml
oc delete -f .bootstrap/4.argocd.yaml
oc delete -f .bootstrap/3.cluster-rolebinding.yaml
oc delete -f .bootstrap/2.subscription.yaml
oc delete -f .bootstrap/1.operatorgroup.clusterwide.yaml
oc delete -f .bootstrap/1.operatorgroup.namespaced.yaml
oc delete -f .bootstrap/0.namespace.yaml

# Clean up the openshift-gitops namespace (created by the operator)
oc delete namespace openshift-gitops
```
