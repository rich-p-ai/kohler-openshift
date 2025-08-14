#!/bin/bash

# Bootstrap Deployment Script for OpenShift GitOps
# This script deploys the YAML files in the .bootstrap folder in the correct order
# and waits for resources to be ready before proceeding to the next step.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BOOTSTRAP_DIR=".bootstrap"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_PATH="${SCRIPT_DIR}/${BOOTSTRAP_DIR}"
DRY_RUN=false
VERBOSE=false
WAIT_TIMEOUT=300  # 5 minutes default timeout

# Function to print colored output
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

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy OpenShift GitOps bootstrap YAML files in the correct order.

OPTIONS:
    -d, --dry-run       Perform a dry run (show what would be deployed without applying)
    -v, --verbose       Enable verbose output
    -t, --timeout SECS  Set timeout for waiting operations (default: 300 seconds)
    -h, --help          Show this help message

EXAMPLES:
    $0                  Deploy all bootstrap files
    $0 --dry-run        Show what would be deployed without applying
    $0 --verbose        Deploy with verbose output
    $0 --timeout 600    Deploy with 10 minute timeout for waiting operations

EOF
}

# Parse command line arguments
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
        -t|--timeout)
            WAIT_TIMEOUT="$2"
            shift 2
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

# Function to check if oc command is available and user is logged in
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v oc &> /dev/null; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    local current_user=$(oc whoami)
    local current_server=$(oc whoami --show-server)
    print_success "Logged in as: ${current_user}"
    print_info "Target server: ${current_server}"
    
    if [[ ! -d "${BOOTSTRAP_PATH}" ]]; then
        print_error "Bootstrap directory not found: ${BOOTSTRAP_PATH}"
        exit 1
    fi
}

# Function to wait for a resource to be ready
wait_for_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-}"
    local timeout="${4:-$WAIT_TIMEOUT}"
    
    local namespace_flag=""
    if [[ -n "$namespace" ]]; then
        namespace_flag="-n $namespace"
    fi
    
    print_info "Waiting for $resource_type/$resource_name to be ready (timeout: ${timeout}s)..."
    
    if $DRY_RUN; then
        print_warning "DRY RUN: Would wait for $resource_type/$resource_name"
        return 0
    fi
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        case $resource_type in
            "namespace")
                if oc get namespace "$resource_name" &> /dev/null; then
                    print_success "$resource_type/$resource_name is ready"
                    return 0
                fi
                ;;
            "subscription")
                if oc get subscription $namespace_flag "$resource_name" -o jsonpath='{.status.state}' 2>/dev/null | grep -q "AtLatestKnown"; then
                    print_success "$resource_type/$resource_name is ready"
                    return 0
                fi
                ;;
            "csv")
                if oc get csv $namespace_flag -o jsonpath='{.items[?(@.spec.displayName=="OpenShift GitOps")].status.phase}' 2>/dev/null | grep -q "Succeeded"; then
                    print_success "OpenShift GitOps CSV is ready"
                    return 0
                fi
                ;;
            "argocd")
                if oc get argocd $namespace_flag "$resource_name" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Available"; then
                    print_success "$resource_type/$resource_name is ready"
                    return 0
                fi
                ;;
            *)
                if oc get $resource_type $namespace_flag "$resource_name" &> /dev/null; then
                    print_success "$resource_type/$resource_name is ready"
                    return 0
                fi
                ;;
        esac
        
        if $VERBOSE; then
            print_info "Still waiting for $resource_type/$resource_name..."
        fi
        sleep 10
    done
    
    print_error "Timeout waiting for $resource_type/$resource_name to be ready"
    return 1
}

# Function to apply a YAML file
apply_yaml() {
    local file="$1"
    local filename=$(basename "$file")
    
    print_info "Applying $filename..."
    
    if $DRY_RUN; then
        print_warning "DRY RUN: Would apply $filename"
        if $VERBOSE; then
            echo "--- Content of $filename ---"
            cat "$file"
            echo "--- End of $filename ---"
        fi
        return 0
    fi
    
    if $VERBOSE; then
        oc apply -f "$file" -v=5
    else
        oc apply -f "$file"
    fi
    
    print_success "Applied $filename"
}

# Function to deploy bootstrap files
deploy_bootstrap() {
    print_info "Starting bootstrap deployment..."
    print_info "Bootstrap directory: $BOOTSTRAP_PATH"
    
    # Get all YAML files in order - use a more robust approach
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$BOOTSTRAP_PATH" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 | sort -z)
    
    if [[ ${#files[@]} -eq 0 ]]; then
        print_error "No YAML files found in $BOOTSTRAP_PATH"
        exit 1
    fi
    
    print_info "Found ${#files[@]} bootstrap files to deploy"
    
    if $DRY_RUN; then
        print_warning "DRY RUN MODE - No changes will be applied"
    fi
    
    # Deploy each file in order with appropriate waits
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        
        case "$filename" in
            "0.namespace.yaml")
                apply_yaml "$file"
                wait_for_resource "namespace" "openshift-gitops-operator"
                ;;
                
            "1.operatorgroup."*)
                apply_yaml "$file"
                # Brief pause to let OperatorGroup be created
                if ! $DRY_RUN; then sleep 5; fi
                ;;
                
            "2.subscription.yaml")
                apply_yaml "$file"
                wait_for_resource "subscription" "openshift-gitops-operator" "openshift-gitops-operator"
                # Wait for the CSV to be installed
                print_info "Waiting for OpenShift GitOps operator to be installed..."
                wait_for_resource "csv" "" "openshift-gitops-operator"
                # Give the operator time to create the openshift-gitops namespace
                if ! $DRY_RUN; then 
                    sleep 30
                    wait_for_resource "namespace" "openshift-gitops"
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
                # Give ArgoCD time to process the ApplicationSet
                if ! $DRY_RUN; then sleep 10; fi
                ;;
                
            *)
                print_warning "Unknown bootstrap file pattern: $filename"
                apply_yaml "$file"
                ;;
        esac
    done
}

# Function to verify deployment
verify_deployment() {
    if $DRY_RUN; then
        print_info "DRY RUN: Skipping deployment verification"
        return 0
    fi
    
    print_info "Verifying deployment..."
    
    # Check if ArgoCD is running
    if oc get pods -n openshift-gitops -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep -q "Running"; then
        print_success "ArgoCD server is running"
    else
        print_warning "ArgoCD server may not be fully ready yet"
    fi
    
    # Check if ApplicationSet exists
    if oc get applicationset root-applications -n openshift-gitops &> /dev/null; then
        print_success "Root ApplicationSet is created"
    else
        print_warning "Root ApplicationSet not found"
    fi
    
    # Show ArgoCD URL
    local argocd_route=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
    if [[ "$argocd_route" != "Not available" ]]; then
        print_success "ArgoCD UI available at: https://$argocd_route"
    fi
}

# Main execution
main() {
    print_info "OpenShift GitOps Bootstrap Deployment Script"
    print_info "============================================="
    
    check_prerequisites
    deploy_bootstrap
    verify_deployment
    
    if $DRY_RUN; then
        print_info "DRY RUN COMPLETED - No changes were applied"
    else
        print_success "Bootstrap deployment completed successfully!"
        print_info ""
        print_info "Next steps:"
        print_info "1. Verify ArgoCD is accessible via the UI"
        print_info "2. Check that Applications are syncing properly"
        print_info "3. Monitor the openshift-gitops namespace for any issues"
    fi
}

# Trap to handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"
