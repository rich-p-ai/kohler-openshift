#!/bin/bash

# Fix for operator group conflicts between OADP and MTC operators
# This script ensures proper separation and cleanup of conflicting resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check login
check_login() {
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    CLUSTER_URL=$(oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    print_info "Connected to cluster: $CLUSTER_URL"
}

# Clean up duplicate operator groups in openshift-migration namespace
cleanup_migration_namespace() {
    print_header "CLEANING UP MIGRATION NAMESPACE"
    
    # Check if we have multiple operator groups
    OPERATOR_GROUPS=$(oc get operatorgroups -n openshift-migration --no-headers 2>/dev/null | wc -l)
    
    if [ "$OPERATOR_GROUPS" -gt 1 ]; then
        print_warning "Found $OPERATOR_GROUPS operator groups in openshift-migration namespace"
        
        # Keep only the migration-operator-group, remove others
        oc get operatorgroups -n openshift-migration --no-headers | while read name rest; do
            if [ "$name" != "migration-operator-group" ]; then
                print_info "Removing duplicate operator group: $name"
                oc delete operatorgroup "$name" -n openshift-migration --ignore-not-found=true
            fi
        done
        
        print_success "Cleaned up duplicate operator groups"
    else
        print_success "No duplicate operator groups found in openshift-migration namespace"
    fi
}

# Clean up any OADP resources in migration namespace
cleanup_oadp_in_migration() {
    print_header "CLEANING UP OADP RESOURCES IN MIGRATION NAMESPACE"
    
    # Remove OADP subscription if it exists in migration namespace
    if oc get subscription redhat-oadp-operator -n openshift-migration &>/dev/null; then
        print_info "Removing OADP subscription from migration namespace"
        oc delete subscription redhat-oadp-operator -n openshift-migration --ignore-not-found=true
    fi
    
    # Remove OADP CSV if it exists in migration namespace
    OADP_CSV=$(oc get csv -n openshift-migration --no-headers 2>/dev/null | grep oadp | awk '{print $1}' || true)
    if [ -n "$OADP_CSV" ]; then
        print_info "Removing OADP CSV from migration namespace: $OADP_CSV"
        oc delete csv "$OADP_CSV" -n openshift-migration --ignore-not-found=true
    fi
    
    print_success "OADP resources cleaned from migration namespace"
}

# Ensure OADP is properly deployed in openshift-adp namespace
verify_oadp_deployment() {
    print_header "VERIFYING OADP DEPLOYMENT"
    
    # Check if openshift-adp namespace exists
    if ! oc get namespace openshift-adp &>/dev/null; then
        print_info "Creating openshift-adp namespace"
        oc create namespace openshift-adp
    fi
    
    # Check OADP subscription
    if oc get subscription redhat-oadp-operator -n openshift-adp &>/dev/null; then
        print_success "OADP subscription found in openshift-adp namespace"
        
        # Check subscription status
        INSTALL_PLAN=$(oc get subscription redhat-oadp-operator -n openshift-adp -o jsonpath='{.status.installplan.name}' 2>/dev/null || echo "")
        if [ -n "$INSTALL_PLAN" ]; then
            print_info "OADP install plan: $INSTALL_PLAN"
        fi
    else
        print_warning "OADP subscription not found in openshift-adp namespace"
        print_info "This should be managed by ArgoCD. Check ArgoCD applications."
    fi
}

# Verify MTC deployment
verify_mtc_deployment() {
    print_header "VERIFYING MTC DEPLOYMENT"
    
    # Check MTC subscription
    if oc get subscription mtc-operator -n openshift-migration &>/dev/null; then
        print_success "MTC subscription found in openshift-migration namespace"
        
        # Check subscription status
        INSTALL_PLAN=$(oc get subscription mtc-operator -n openshift-migration -o jsonpath='{.status.installplan.name}' 2>/dev/null || echo "")
        if [ -n "$INSTALL_PLAN" ]; then
            print_info "MTC install plan: $INSTALL_PLAN"
        fi
    else
        print_warning "MTC subscription not found in openshift-migration namespace"
    fi
}

# Check CSV status
check_csv_status() {
    print_header "CHECKING OPERATOR STATUS"
    
    echo "OADP Operator Status:"
    oc get csv -n openshift-adp 2>/dev/null || echo "  No CSV found in openshift-adp"
    
    echo ""
    echo "MTC Operator Status:"
    oc get csv -n openshift-migration 2>/dev/null || echo "  No CSV found in openshift-migration"
}

# Check ArgoCD applications
check_argocd_apps() {
    print_header "CHECKING ARGOCD APPLICATIONS"
    
    echo "OADP Related Applications:"
    oc get applications -n openshift-gitops | grep -E "(oadp|adp)" || echo "  No OADP applications found"
    
    echo ""
    echo "MTC Related Applications:"
    oc get applications -n openshift-gitops | grep -E "(mtc|migration)" || echo "  No MTC applications found"
}

# Main execution
main() {
    print_header "OPERATOR CONFLICT RESOLUTION TOOL"
    print_info "This script will fix operator group conflicts between OADP and MTC"
    
    check_login
    cleanup_migration_namespace
    cleanup_oadp_in_migration
    verify_oadp_deployment
    verify_mtc_deployment
    check_csv_status
    check_argocd_apps
    
    print_header "NEXT STEPS"
    print_info "1. Commit and push the updated configurations to Git repository"
    print_info "2. Sync ArgoCD applications to apply the fixed configurations"
    print_info "3. Monitor operator installation progress"
    print_info "4. Run this script again to verify the fix"
    
    print_success "Operator conflict resolution completed!"
}

# Run main function
main "$@"
