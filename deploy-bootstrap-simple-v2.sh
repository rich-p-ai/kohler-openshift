#!/bin/bash

# Bootstrap Deployment Script for OpenShift GitOps
# Simplified version that works better with Git Bash on Windows

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BOOTSTRAP_DIR=".bootstrap"
DRY_RUN=false
VERBOSE=false

print_info() {
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

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy OpenShift GitOps bootstrap YAML files in the correct order.

OPTIONS:
    -d, --dry-run       Perform a dry run
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v oc >/dev/null 2>&1; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    
    if ! oc whoami >/dev/null 2>&1; then
        print_error "Not logged into OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    CURRENT_USER=$(oc whoami)
    CURRENT_SERVER=$(oc whoami --show-server)
    print_success "Logged in as: ${CURRENT_USER}"
    print_info "Target server: ${CURRENT_SERVER}"
    
    if [[ ! -d "${BOOTSTRAP_DIR}" ]]; then
        print_error "Bootstrap directory not found: ${BOOTSTRAP_DIR}"
        exit 1
    fi
}

# Apply a YAML file
apply_yaml() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    
    print_info "Applying $filename..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would apply $filename"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "--- Content of $filename ---"
            cat "$file"
            echo "--- End of $filename ---"
        fi
        return 0
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        oc apply -f "$file" -v=5
    else
        oc apply -f "$file"
    fi
    
    print_success "Applied $filename"
}

# Wait for resource
wait_for_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="$3"
    local timeout=300
    
    print_info "Waiting for $resource_type/$resource_name to be ready..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would wait for $resource_type/$resource_name"
        return 0
    fi
    
    local count=0
    local max_count=$((timeout / 10))
    
    while [[ $count -lt $max_count ]]; do
        case $resource_type in
            "namespace")
                if oc get namespace "$resource_name" >/dev/null 2>&1; then
                    print_success "$resource_type/$resource_name is ready"
                    return 0
                fi
                ;;
            "subscription")
                if oc get subscription -n "$namespace" "$resource_name" -o jsonpath='{.status.state}' 2>/dev/null | grep -q "AtLatestKnown"; then
                    print_success "$resource_type/$resource_name is ready"
                    return 0
                fi
                ;;
            "csv")
                if oc get csv -n "$namespace" -o jsonpath='{.items[?(@.spec.displayName=="OpenShift GitOps")].status.phase}' 2>/dev/null | grep -q "Succeeded"; then
                    print_success "OpenShift GitOps CSV is ready"
                    return 0
                fi
                ;;
            "argocd")
                if oc get argocd -n "$namespace" "$resource_name" >/dev/null 2>&1; then
                    print_success "$resource_type/$resource_name is ready"
                    return 0
                fi
                ;;
        esac
        
        if [[ "$VERBOSE" == "true" ]]; then
            print_info "Still waiting for $resource_type/$resource_name... ($count/$max_count)"
        fi
        sleep 10
        count=$((count + 1))
    done
    
    print_error "Timeout waiting for $resource_type/$resource_name"
    return 1
}

# Main deployment function
deploy_bootstrap() {
    print_info "Starting bootstrap deployment..."
    print_info "Bootstrap directory: $(pwd)/${BOOTSTRAP_DIR}"
    
    # Get files in order
    FILES=()
    for file in "${BOOTSTRAP_DIR}"/*.yaml "${BOOTSTRAP_DIR}"/*.yml; do
        if [[ -f "$file" ]]; then
            FILES+=("$file")
        fi
    done
    
    # Sort files
    IFS=$'\n' FILES=($(sort <<<"${FILES[*]}"))
    unset IFS
    
    if [[ ${#FILES[@]} -eq 0 ]]; then
        print_error "No YAML files found in $BOOTSTRAP_DIR"
        exit 1
    fi
    
    print_info "Found ${#FILES[@]} bootstrap files to deploy"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN MODE - No changes will be applied"
        print_info "Files to be deployed:"
        for file in "${FILES[@]}"; do
            print_info "  - $(basename "$file")"
        done
    fi
    
    # Deploy each file
    for file in "${FILES[@]}"; do
        filename=$(basename "$file")
        
        case "$filename" in
            "0.namespace.yaml")
                apply_yaml "$file"
                wait_for_resource "namespace" "openshift-gitops-operator" ""
                ;;
                
            "1.operatorgroup."*)
                apply_yaml "$file"
                if [[ "$DRY_RUN" != "true" ]]; then sleep 5; fi
                ;;
                
            "2.subscription.yaml")
                apply_yaml "$file"
                wait_for_resource "subscription" "openshift-gitops-operator" "openshift-gitops-operator"
                print_info "Waiting for OpenShift GitOps operator to be installed..."
                wait_for_resource "csv" "" "openshift-gitops-operator"
                if [[ "$DRY_RUN" != "true" ]]; then 
                    sleep 30
                    wait_for_resource "namespace" "openshift-gitops" ""
                fi
                ;;
                
            "3.cluster-rolebinding.yaml")
                apply_yaml "$file"
                ;;
                
            "4.argocd.yaml")
                apply_yaml "$file"
                wait_for_resource "argocd" "openshift-gitops" "openshift-gitops"
                ;;
                
            "5.repository-secret.yaml")
                apply_yaml "$file"
                ;;
                
            "6.root-application.yaml")
                apply_yaml "$file"
                if [[ "$DRY_RUN" != "true" ]]; then sleep 10; fi
                ;;
                
            *)
                print_warning "Unknown bootstrap file pattern: $filename"
                apply_yaml "$file"
                ;;
        esac
    done
}

# Verify deployment
verify_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Skipping deployment verification"
        return 0
    fi
    
    print_info "Verifying deployment..."
    
    # Check ArgoCD pods
    if oc get pods -n openshift-gitops -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep -q "Running"; then
        print_success "ArgoCD server is running"
    else
        print_warning "ArgoCD server may not be fully ready yet"
    fi
    
    # Check ApplicationSet
    if oc get applicationset root-applications -n openshift-gitops >/dev/null 2>&1; then
        print_success "Root ApplicationSet is created"
    else
        print_warning "Root ApplicationSet not found"
    fi
    
    # Show ArgoCD URL
    ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
    if [[ "$ARGOCD_ROUTE" != "Not available" ]]; then
        print_success "ArgoCD UI available at: https://$ARGOCD_ROUTE"
    fi
}

# Main function
main() {
    print_info "OpenShift GitOps Bootstrap Deployment Script"
    print_info "============================================="
    
    check_prerequisites
    deploy_bootstrap
    verify_deployment
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN COMPLETED - No changes were applied"
    else
        print_success "Bootstrap deployment completed successfully!"
        echo ""
        print_info "Next steps:"
        print_info "1. Verify ArgoCD is accessible via the UI"
        print_info "2. Check that Applications are syncing properly"
        print_info "3. Monitor the openshift-gitops namespace for any issues"
    fi
}

# Run main function
main "$@"
