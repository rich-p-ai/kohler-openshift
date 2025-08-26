#!/bin/bash

# MTC Setup Script for ocp-prd to ocp2 Migration
# This script sets up the Migration Toolkit for Containers

set -e

echo "🚀 Setting up Migration Toolkit for Containers (MTC)"
echo "📋 Migration Direction: ocp-prd → ocp2"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if oc command is available
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed or not in PATH"
        exit 1
    fi
    
    print_success "OpenShift CLI found"
}

# Setup source cluster (ocp-prd)
setup_source_cluster() {
    print_status "Setting up source cluster (ocp-prd)..."
    
    # Login to ocp-prd
    print_status "Logging into ocp-prd..."
    oc login -u kubeadmin -p KUHNz-u7GkB-rZFdo-u6FVV --server=https://api.ocp-prd.kohlerco.com:6443 --insecure-skip-tls-verify
    
    # Create namespace and service account
    print_status "Creating namespace and service account in ocp-prd..."
    oc create namespace openshift-migration --dry-run=client -o yaml | oc apply -f -
    oc create serviceaccount migration-sa -n openshift-migration --dry-run=client -o yaml | oc apply -f -
    oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-migration:migration-sa
    
    # Get service account token
    print_status "Getting service account token from ocp-prd..."
    SA_SECRET=$(oc get sa migration-sa -n openshift-migration -o jsonpath='{.secrets[0].name}')
    SA_TOKEN=$(oc get secret $SA_SECRET -n openshift-migration -o jsonpath='{.data.token}' | base64 -d)
    
    print_success "Source cluster setup complete"
    echo "Service Account Token: $SA_TOKEN"
}

# Setup target cluster (ocp2)
setup_target_cluster() {
    print_status "Setting up target cluster (ocp2)..."
    
    # Login to ocp2
    print_status "Logging into ocp2..."
    oc login -u kubeadmin -p FUKeF-MWGqX-H52Et-8wx5T --server=https://api.ocp2.kohlerco.com:6443 --insecure-skip-tls-verify
    
    # Create namespace and service account
    print_status "Creating namespace and service account in ocp2..."
    oc create namespace openshift-migration --dry-run=client -o yaml | oc apply -f -
    oc create serviceaccount migration-sa -n openshift-migration --dry-run=client -o yaml | oc apply -f -
    oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-migration:migration-sa
    
    # Get service account token
    print_status "Getting service account token from ocp2..."
    SA_SECRET=$(oc get sa migration-sa -n openshift-migration -o jsonpath='{.secrets[0].name}')
    SA_TOKEN=$(oc get secret $SA_SECRET -n openshift-migration -o jsonpath='{.data.token}' | base64 -d)
    
    print_success "Target cluster setup complete"
    echo "Service Account Token: $SA_TOKEN"
}

# Deploy MTC operator
deploy_mtc_operator() {
    print_status "Deploying MTC operator..."
    
    # Apply all MTC configurations
    print_status "Applying MTC configurations..."
    oc apply -f namespace.yaml
    oc apply -f operator-group.yaml
    oc apply -f subscription.yaml
    
    # Wait for operator to be ready
    print_status "Waiting for MTC operator to be ready..."
    oc wait --for=condition=Installed csv/mtc-operator -n openshift-migration --timeout=300s
    
    print_success "MTC operator deployed successfully"
}

# Verify installation
verify_installation() {
    print_status "Verifying MTC installation..."
    
    # Check operator status
    print_status "Checking operator status..."
    oc get csv -n openshift-migration
    
    # Check if operator is running
    if oc get deployment mtc-operator -n openshift-migration &>/dev/null; then
        print_success "MTC operator is running"
    else
        print_warning "MTC operator deployment not found yet"
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "MTC Setup for ocp-prd → ocp2 Migration"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    
    echo ""
    echo "Choose setup option:"
    echo "1) Setup source cluster (ocp-prd) only"
    echo "2) Setup target cluster (ocp2) only"
    echo "3) Setup both clusters"
    echo "4) Deploy MTC operator only"
    echo "5) Full setup (both clusters + MTC operator)"
    echo ""
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            setup_source_cluster
            ;;
        2)
            setup_target_cluster
            ;;
        3)
            setup_source_cluster
            echo ""
            setup_target_cluster
            ;;
        4)
            deploy_mtc_operator
            ;;
        5)
            setup_source_cluster
            echo ""
            setup_target_cluster
            echo ""
            deploy_mtc_operator
            echo ""
            verify_installation
            ;;
        *)
            print_error "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    
    echo ""
    print_success "Setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Update service account tokens in secret files"
    echo "2. Deploy via ArgoCD: oc apply -f argocd-application.yaml"
    echo "3. Create migration plan and execute migration"
    echo ""
    echo "See README.md for detailed instructions"
}

# Run main function
main "$@"
