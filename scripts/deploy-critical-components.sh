#!/bin/bash

# OpenShift Critical Infrastructure Components Deployment Script
# This script deploys critical infrastructure components to OCP-DEV cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_API="https://api.ocp-dev.kohlerco.com:6443"
CLUSTER_DOMAIN="apps.ocp-dev.kohlerco.com"
REPO_URL="https://github.com/rich-p-ai/kohler-openshift.git"
ARGOCD_NAMESPACE="openshift-gitops"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    log_info "Waiting for pods in namespace '$namespace' to be ready (timeout: ${timeout}s)..."
    
    oc wait --for=condition=Ready pods --all -n "$namespace" --timeout="${timeout}s" || {
        log_warning "Some pods in '$namespace' may still be starting. Continuing..."
        oc get pods -n "$namespace"
    }
}

wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    log_info "Waiting for deployment '$deployment' in namespace '$namespace'..."
    
    oc rollout status deployment/"$deployment" -n "$namespace" --timeout="${timeout}s"
}

check_cluster_access() {
    log_info "Checking cluster access..."
    
    if ! oc whoami &>/dev/null; then
        log_error "Not logged into OpenShift cluster. Please login first:"
        echo "oc login --server=$CLUSTER_API"
        exit 1
    fi
    
    local user=$(oc whoami)
    log_success "Logged in as: $user"
    
    if ! oc auth can-i "*" "*" --all-namespaces &>/dev/null; then
        log_error "Insufficient permissions. You need cluster-admin access."
        exit 1
    fi
    
    log_success "Cluster admin permissions verified"
}

check_secrets() {
    log_info "Checking required secrets..."
    
    # Check if Azure AD secret has placeholder value
    if grep -q "REPLACE_WITH_ACTUAL_AZURE_AD_CLIENT_SECRET" components/oauth-configuration/azure-ad-client-secret.yaml; then
        log_warning "Azure AD client secret contains placeholder value"
        log_info "Please update the secret before deploying OAuth configuration:"
        echo "  1. Edit components/oauth-configuration/azure-ad-client-secret.yaml"
        echo "  2. Replace placeholder with actual client secret"
        echo "  3. Or apply the secret manually: oc apply -f components/oauth-configuration/azure-ad-client-secret.yaml"
        echo ""
    fi
    
    # Check if OADP secret has placeholder value
    if [[ -f "components/oadp-configuration/backup-storage-credentials.yaml" ]] && grep -q "YOUR_" components/oadp-configuration/backup-storage-credentials.yaml; then
        log_warning "OADP backup credentials contain placeholder values"
        log_info "Please update backup credentials before deploying OADP:"
        echo "  1. Edit components/oadp-configuration/backup-storage-credentials.yaml"
        echo "  2. Replace placeholders with actual S3 credentials"
        echo "  3. Or apply the secret manually: oc apply -f components/oadp-configuration/backup-storage-credentials.yaml"
        echo ""
    fi
    
    echo "For production deployments, see docs/SECRETS-MANAGEMENT.md for best practices."
    echo ""
}

install_gitops_operator() {
    log_info "Installing GitOps operator..."
    
    # Check if operator is already installed
    if oc get csv -n openshift-gitops-operator 2>/dev/null | grep -q openshift-gitops; then
        log_success "GitOps operator already installed"
        return 0
    fi
    
    # Apply GitOps operator configuration
    oc apply -k components/gitops-operator/
    
    # Wait for operator to be ready
    log_info "Waiting for GitOps operator to be ready..."
    sleep 30
    
    # Wait for the subscription to create CSV
    local retries=0
    while [[ $retries -lt 20 ]]; do
        if oc get csv -n openshift-gitops-operator 2>/dev/null | grep -q openshift-gitops; then
            break
        fi
        log_info "Waiting for GitOps operator CSV... (attempt $((retries+1))/20)"
        sleep 15
        ((retries++))
    done
    
    if [[ $retries -eq 20 ]]; then
        log_error "Timeout waiting for GitOps operator CSV"
        return 1
    fi
    
    # Wait for operator pods
    wait_for_pods "openshift-gitops-operator" 300
    
    # Wait for ArgoCD namespace to be created
    local retries=0
    while [[ $retries -lt 10 ]]; do
        if oc get namespace openshift-gitops &>/dev/null; then
            break
        fi
        log_info "Waiting for openshift-gitops namespace... (attempt $((retries+1))/10)"
        sleep 10
        ((retries++))
    done
    
    log_success "GitOps operator installed successfully"
}

configure_gitops() {
    log_info "Configuring ArgoCD cluster..."
    
    # Apply GitOps configuration
    oc apply -k components/gitops-configuration/
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD components to be ready..."
    sleep 30
    
    # Wait for ArgoCD server deployment
    wait_for_deployment "$ARGOCD_NAMESPACE" "openshift-gitops-server" 600
    
    # Wait for all ArgoCD pods
    wait_for_pods "$ARGOCD_NAMESPACE" 600
    
    log_success "ArgoCD cluster configured successfully"
}

deploy_applications() {
    log_info "Deploying critical infrastructure applications..."
    
    # Apply the app-of-apps pattern
    oc apply -k clusters/dev/
    
    # Wait a moment for applications to be created
    sleep 15
    
    # Check if applications are created
    local app_count=$(oc get applications -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    log_info "Created $app_count applications"
    
    if [[ $app_count -eq 0 ]]; then
        log_warning "No applications found. This might be expected if using Helm charts."
        return 0
    fi
    
    # List applications
    log_info "Applications created:"
    oc get applications -n "$ARGOCD_NAMESPACE" --no-headers | awk '{print "  - " $1 " (" $3 ")"}'
    
    log_success "Applications deployed successfully"
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check ArgoCD UI accessibility
    local argocd_route=$(oc get route openshift-gitops-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [[ -n "$argocd_route" ]]; then
        log_success "ArgoCD UI available at: https://$argocd_route"
    else
        log_warning "ArgoCD route not found or not ready yet"
    fi
    
    # Check operator status
    log_info "Checking operator status..."
    
    # GitOps operator
    if oc get csv -n openshift-gitops-operator 2>/dev/null | grep -q "Succeeded"; then
        log_success "✅ GitOps operator: Ready"
    else
        log_warning "⚠️  GitOps operator: Not ready"
    fi
    
    # ArgoCD pods
    local ready_pods=$(oc get pods -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    local total_pods=$(oc get pods -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ $ready_pods -gt 0 && $ready_pods -eq $total_pods ]]; then
        log_success "✅ ArgoCD pods: $ready_pods/$total_pods Ready"
    else
        log_warning "⚠️  ArgoCD pods: $ready_pods/$total_pods Ready"
    fi
    
    # Applications (if any)
    local app_count=$(oc get applications -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ $app_count -gt 0 ]]; then
        local synced_apps=$(oc get applications -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | grep -c "Synced" || echo "0")
        log_info "Applications: $synced_apps/$app_count Synced"
    fi
}

show_next_steps() {
    echo ""
    echo "=========================="
    echo "🎉 Deployment Complete!"
    echo "=========================="
    echo ""
    echo "Next steps:"
    echo "1. Access ArgoCD UI:"
    local argocd_route=$(oc get route openshift-gitops-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "openshift-gitops-server-openshift-gitops.apps.ocp-dev.kohlerco.com")
    echo "   https://$argocd_route"
    echo ""
    echo "2. Get ArgoCD admin password:"
    echo "   oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-"
    echo ""
    echo "3. Monitor application deployment:"
    echo "   oc get applications -n openshift-gitops -w"
    echo ""
    echo "4. Check component status:"
    echo "   ./scripts/verify-deployment.sh"
    echo ""
    echo "5. View deployment documentation:"
    echo "   cat docs/CRITICAL-COMPONENTS-DEPLOYMENT.md"
    echo ""
}

# Main execution
main() {
    echo "========================================"
    echo "🚀 OCP-DEV Critical Infrastructure Deployment"
    echo "========================================"
    echo ""
    
    # Preflight checks
    check_cluster_access
    check_secrets
    
    # Phase 1: Install GitOps operator
    log_info "Phase 1: Installing GitOps operator..."
    install_gitops_operator
    
    # Phase 2: Configure ArgoCD
    log_info "Phase 2: Configuring ArgoCD cluster..."
    configure_gitops
    
    # Phase 3: Deploy applications
    log_info "Phase 3: Deploying critical infrastructure applications..."
    deploy_applications
    
    # Verification
    log_info "Phase 4: Verifying deployment..."
    verify_deployment
    
    # Show next steps
    show_next_steps
}

# Run main function
main "$@"
