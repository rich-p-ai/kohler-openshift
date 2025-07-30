#!/bin/bash

# OpenShift Critical Infrastructure Components Verification Script
# This script verifies the status of critical infrastructure components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅ SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠️  WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[❌ ERROR]${NC} $1"
}

check_component() {
    local component=$1
    local namespace=$2
    local resource_type=$3
    local resource_name=$4
    local expected_status=$5
    
    echo -n "Checking $component... "
    
    if ! oc get "$resource_type" "$resource_name" -n "$namespace" &>/dev/null; then
        log_error "$component not found"
        return 1
    fi
    
    local status=$(oc get "$resource_type" "$resource_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    if [[ "$status" == "$expected_status" ]] || [[ -z "$expected_status" ]]; then
        log_success "$component: Ready"
        return 0
    else
        log_warning "$component: $status (expected: $expected_status)"
        return 1
    fi
}

check_pods() {
    local namespace=$1
    local component=$2
    
    echo -n "Checking $component pods... "
    
    if ! oc get namespace "$namespace" &>/dev/null; then
        log_error "Namespace $namespace not found"
        return 1
    fi
    
    local total_pods=$(oc get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local running_pods=$(oc get pods -n "$namespace" --no-headers 2>/dev/null | grep -c "Running\|Completed" || echo "0")
    
    if [[ $total_pods -eq 0 ]]; then
        log_warning "$component: No pods found"
        return 1
    elif [[ $running_pods -eq $total_pods ]]; then
        log_success "$component: $running_pods/$total_pods pods ready"
        return 0
    else
        log_warning "$component: $running_pods/$total_pods pods ready"
        return 1
    fi
}

check_operator() {
    local namespace=$1
    local operator_name=$2
    local component=$3
    
    echo -n "Checking $component operator... "
    
    local csv_status=$(oc get csv -n "$namespace" --no-headers 2>/dev/null | grep "$operator_name" | awk '{print $NF}' || echo "NotFound")
    
    if [[ "$csv_status" == "Succeeded" ]]; then
        log_success "$component operator: Installed"
        return 0
    else
        log_warning "$component operator: $csv_status"
        return 1
    fi
}

verify_gitops() {
    echo ""
    echo "=== GitOps Components ==="
    
    # GitOps operator
    check_operator "openshift-gitops-operator" "openshift-gitops-operator" "GitOps"
    
    # GitOps operator pods
    check_pods "openshift-gitops-operator" "GitOps Operator"
    
    # ArgoCD cluster
    check_component "ArgoCD Cluster" "openshift-gitops" "argocd" "openshift-gitops" ""
    
    # ArgoCD pods
    check_pods "openshift-gitops" "ArgoCD"
    
    # ArgoCD route
    echo -n "Checking ArgoCD route... "
    if oc get route openshift-gitops-server -n openshift-gitops &>/dev/null; then
        local argocd_url=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
        log_success "ArgoCD UI: https://$argocd_url"
    else
        log_warning "ArgoCD route not found"
    fi
}

verify_network() {
    echo ""
    echo "=== Network Components ==="
    
    # Cluster network
    echo -n "Checking cluster network... "
    if oc get network cluster &>/dev/null; then
        local network_type=$(oc get network cluster -o jsonpath='{.spec.networkType}')
        log_success "Cluster network: $network_type"
    else
        log_error "Cluster network configuration not found"
    fi
    
    # Ingress controller
    echo -n "Checking ingress controller... "
    if oc get ingresscontroller default -n openshift-ingress-operator &>/dev/null; then
        local ingress_available=$(oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
        if [[ "$ingress_available" == "True" ]]; then
            log_success "Ingress controller: Available"
        else
            log_warning "Ingress controller: Not available"
        fi
    else
        log_error "Ingress controller not found"
    fi
    
    # Ingress pods
    check_pods "openshift-ingress" "Ingress"
}

verify_registry() {
    echo ""
    echo "=== Image Registry ==="
    
    # Registry configuration
    echo -n "Checking image registry config... "
    if oc get config.imageregistry.operator.openshift.io cluster &>/dev/null; then
        local registry_state=$(oc get config.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.managementState}')
        if [[ "$registry_state" == "Managed" ]]; then
            log_success "Image registry: $registry_state"
        else
            log_warning "Image registry: $registry_state"
        fi
    else
        log_error "Image registry configuration not found"
    fi
    
    # Registry pods
    check_pods "openshift-image-registry" "Image Registry"
    
    # Registry storage
    echo -n "Checking registry storage... "
    if oc get pvc image-registry-storage -n openshift-image-registry &>/dev/null; then
        local pvc_status=$(oc get pvc image-registry-storage -n openshift-image-registry -o jsonpath='{.status.phase}')
        if [[ "$pvc_status" == "Bound" ]]; then
            log_success "Registry storage: $pvc_status"
        else
            log_warning "Registry storage: $pvc_status"
        fi
    else
        log_warning "Registry storage PVC not found"
    fi
}

verify_storage() {
    echo ""
    echo "=== Storage Components ==="
    
    # ODF operator
    check_operator "openshift-storage" "odf-operator" "ODF"
    
    # ODF pods
    check_pods "openshift-storage" "ODF"
    
    # Storage cluster
    echo -n "Checking storage cluster... "
    if oc get storagecluster -n openshift-storage &>/dev/null; then
        local sc_count=$(oc get storagecluster -n openshift-storage --no-headers | wc -l)
        log_success "Storage clusters: $sc_count found"
    else
        log_warning "No storage clusters found"
    fi
    
    # Storage classes
    echo -n "Checking storage classes... "
    local sc_count=$(oc get storageclass --no-headers | wc -l)
    local odf_sc_count=$(oc get storageclass --no-headers | grep -c "ocs-\|odf-" || echo "0")
    log_info "Storage classes: $sc_count total, $odf_sc_count ODF"
}

verify_backup() {
    echo ""
    echo "=== Backup Components ==="
    
    # OADP operator
    check_operator "openshift-adp" "oadp-operator" "OADP"
    
    # OADP pods
    check_pods "openshift-adp" "OADP"
    
    # Data Protection Application
    echo -n "Checking DataProtectionApplication... "
    if oc get dataprotectionapplication -n openshift-adp &>/dev/null; then
        local dpa_count=$(oc get dataprotectionapplication -n openshift-adp --no-headers | wc -l)
        log_success "DataProtectionApplication: $dpa_count configured"
    else
        log_warning "DataProtectionApplication not found"
    fi
    
    # Backup schedules
    echo -n "Checking backup schedules... "
    if oc get schedule -n openshift-adp &>/dev/null; then
        local schedule_count=$(oc get schedule -n openshift-adp --no-headers | wc -l)
        log_success "Backup schedules: $schedule_count configured"
    else
        log_warning "Backup schedules not found"
    fi
}

verify_authentication() {
    echo ""
    echo "=== Authentication ==="
    
    # OAuth configuration
    echo -n "Checking OAuth configuration... "
    if oc get oauth cluster &>/dev/null; then
        local oauth_providers=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[*].name}' | wc -w)
        if [[ $oauth_providers -gt 0 ]]; then
            log_success "OAuth providers: $oauth_providers configured"
        else
            log_warning "No OAuth providers configured"
        fi
    else
        log_error "OAuth configuration not found"
    fi
    
    # Azure AD secret
    echo -n "Checking Azure AD client secret... "
    if oc get secret azure-ad-client-secret -n openshift-config &>/dev/null; then
        log_success "Azure AD client secret: Present"
    else
        log_warning "Azure AD client secret not found"
    fi
}

verify_applications() {
    echo ""
    echo "=== ArgoCD Applications ==="
    
    if ! oc get applications -n openshift-gitops &>/dev/null; then
        log_warning "No ArgoCD applications found"
        return
    fi
    
    local total_apps=$(oc get applications -n openshift-gitops --no-headers | wc -l)
    local synced_apps=$(oc get applications -n openshift-gitops --no-headers | grep -c "Synced" || echo "0")
    local healthy_apps=$(oc get applications -n openshift-gitops --no-headers | grep -c "Healthy" || echo "0")
    
    echo "Application Status:"
    echo "  Total: $total_apps"
    echo "  Synced: $synced_apps"
    echo "  Healthy: $healthy_apps"
    
    if [[ $total_apps -gt 0 ]]; then
        echo ""
        echo "Application Details:"
        oc get applications -n openshift-gitops --no-headers | while read -r line; do
            local app_name=$(echo "$line" | awk '{print $1}')
            local sync_status=$(echo "$line" | awk '{print $2}')
            local health_status=$(echo "$line" | awk '{print $3}')
            
            if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
                echo -e "  ${GREEN}✅${NC} $app_name: $sync_status, $health_status"
            elif [[ "$sync_status" == "Synced" ]]; then
                echo -e "  ${YELLOW}⚠️${NC} $app_name: $sync_status, $health_status"
            else
                echo -e "  ${RED}❌${NC} $app_name: $sync_status, $health_status"
            fi
        done
    fi
}

show_summary() {
    echo ""
    echo "=========================="
    echo "📊 Verification Summary"
    echo "=========================="
    echo ""
    echo "Core Infrastructure:"
    echo "  - GitOps: ArgoCD managing cluster configuration"
    echo "  - Network: OVN-Kubernetes with ingress controllers"
    echo "  - Registry: Internal image registry with persistent storage"
    echo ""
    echo "Storage & Backup:"
    echo "  - Storage: OpenShift Data Foundation (ODF)"
    echo "  - Backup: OpenShift API for Data Protection (OADP)"
    echo ""
    echo "Security:"
    echo "  - Authentication: OAuth with Azure AD integration"
    echo "  - Certificates: Cert-Manager for automated certificate management"
    echo ""
    echo "Useful Commands:"
    echo "  - View ArgoCD UI: oc get route openshift-gitops-server -n openshift-gitops"
    echo "  - Get ArgoCD password: oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-"
    echo "  - Monitor apps: oc get applications -n openshift-gitops -w"
    echo "  - Check operators: oc get csv -A"
    echo ""
}

# Main execution
main() {
    echo "========================================"
    echo "🔍 OCP-DEV Infrastructure Verification"
    echo "========================================"
    
    # Check cluster access
    if ! oc whoami &>/dev/null; then
        log_error "Not logged into OpenShift cluster. Please login first."
        exit 1
    fi
    
    local user=$(oc whoami)
    local cluster=$(oc whoami --show-server)
    echo "Logged in as: $user"
    echo "Cluster: $cluster"
    
    # Run verification checks
    verify_gitops
    verify_network
    verify_registry
    verify_storage
    verify_backup
    verify_authentication
    verify_applications
    
    # Show summary
    show_summary
}

# Run main function
main "$@"
