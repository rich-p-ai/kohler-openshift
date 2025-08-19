#!/bin/bash

# Script to copy OADP cloud credentials from OCP-HOST to OCP2 cluster
# This script automates the credential copying process for cross-cluster OADP deployment

set -e

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

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Function to check if logged into cluster
check_cluster_login() {
    local cluster_name=$1
    local context=$(oc config current-context 2>/dev/null || echo "")
    
    if [[ -z "$context" ]]; then
        print_error "Not logged into any OpenShift cluster. Please login first."
        return 1
    fi
    
    print_status "Current cluster context: $context"
    return 0
}

# Function to login to cluster
login_to_cluster() {
    local cluster_name=$1
    local api_url=""
    local username=""
    local password=""
    
    case $cluster_name in
        "ocp-host")
            api_url="https://api.ocp-host.kohlerco.com:6443"
            username="kubeadmin"
            print_status "Please provide password for OCP-HOST cluster (kubeadmin):"
            read -s password
            ;;
        "ocp2")
            api_url="https://api.ocp2.kohlerco.com:6443"
            username="kubeadmin"
            print_status "Please provide password for OCP2 cluster (kubeadmin):"
            read -s password
            ;;
        *)
            print_error "Unknown cluster: $cluster_name"
            return 1
            ;;
    esac
    
    print_status "Logging into $cluster_name cluster..."
    if oc login -u $username -p "$password" --server=$api_url --insecure-skip-tls-verify; then
        print_success "Successfully logged into $cluster_name cluster"
        return 0
    else
        print_error "Failed to login to $cluster_name cluster"
        return 1
    fi
}

# Function to export credentials from OCP-HOST
export_credentials() {
    print_status "Exporting cloud credentials from OCP-HOST cluster..."
    
    # Check if secret exists
    if ! oc get secret cloud-credentials -n openshift-adp &>/dev/null; then
        print_error "cloud-credentials secret not found in openshift-adp namespace on OCP-HOST"
        print_status "Checking if openshift-adp namespace exists..."
        if ! oc get namespace openshift-adp &>/dev/null; then
            print_error "openshift-adp namespace does not exist on OCP-HOST"
            print_status "OADP may not be installed on OCP-HOST yet"
            return 1
        fi
        return 1
    fi
    
    # Export the secret
    local temp_file="/tmp/cloud-credentials-ocp-host.yaml"
    oc get secret cloud-credentials -n openshift-adp -o yaml > $temp_file
    
    if [[ -f "$temp_file" ]]; then
        print_success "Credentials exported to $temp_file"
        echo $temp_file
    else
        print_error "Failed to export credentials"
        return 1
    fi
}

# Function to import credentials to OCP2
import_credentials() {
    local credentials_file=$1
    
    print_status "Importing cloud credentials to OCP2 cluster..."
    
    # Check if secret already exists
    if oc get secret cloud-credentials -n openshift-adp &>/dev/null; then
        print_warning "cloud-credentials secret already exists in openshift-adp namespace on OCP2"
        print_status "Do you want to replace it? (y/N):"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_status "Skipping credential import"
            return 0
        fi
        
        print_status "Deleting existing secret..."
        oc delete secret cloud-credentials -n openshift-adp
    fi
    
    # Import the secret
    if oc apply -f $credentials_file; then
        print_success "Successfully imported cloud credentials to OCP2"
        return 0
    else
        print_error "Failed to import cloud credentials to OCP2"
        return 1
    fi
}

# Function to verify OADP setup on OCP2
verify_oadp_setup() {
    print_status "Verifying OADP setup on OCP2 cluster..."
    
    # Check namespace
    if oc get namespace openshift-adp &>/dev/null; then
        print_success "openshift-adp namespace exists"
    else
        print_error "openshift-adp namespace does not exist"
        return 1
    fi
    
    # Check operator subscription
    if oc get subscription oadp-operator -n openshift-adp &>/dev/null; then
        print_success "OADP operator subscription exists"
    else
        print_warning "OADP operator subscription not found (may still be deploying)"
    fi
    
    # Check cloud credentials
    if oc get secret cloud-credentials -n openshift-adp &>/dev/null; then
        print_success "cloud-credentials secret exists"
    else
        print_error "cloud-credentials secret not found"
        return 1
    fi
    
    # Check DataProtectionApplication
    if oc get dpa cluster-velero-config -n openshift-adp &>/dev/null; then
        print_success "DataProtectionApplication exists"
        
        # Check status
        local dpa_status=$(oc get dpa cluster-velero-config -n openshift-adp -o jsonpath='{.status.conditions[?(@.type=="Reconciled")].status}' 2>/dev/null || echo "Unknown")
        print_status "DataProtectionApplication status: $dpa_status"
    else
        print_warning "DataProtectionApplication not found (may still be deploying)"
    fi
    
    print_success "OADP setup verification completed"
}

# Main execution
main() {
    print_status "Starting OADP credential copy process..."
    
    # Check prerequisites
    check_command "oc"
    
    # Step 1: Login to OCP-HOST and export credentials
    print_status "Step 1: Exporting credentials from OCP-HOST"
    if ! login_to_cluster "ocp-host"; then
        exit 1
    fi
    
    local credentials_file=$(export_credentials)
    if [[ -z "$credentials_file" ]]; then
        exit 1
    fi
    
    # Step 2: Login to OCP2 and import credentials
    print_status "Step 2: Importing credentials to OCP2"
    if ! login_to_cluster "ocp2"; then
        exit 1
    fi
    
    if ! import_credentials "$credentials_file"; then
        exit 1
    fi
    
    # Step 3: Verify setup
    print_status "Step 3: Verifying OADP setup on OCP2"
    if ! verify_oadp_setup; then
        print_warning "OADP setup verification failed. Please check manually."
    fi
    
    # Cleanup
    if [[ -f "$credentials_file" ]]; then
        rm -f "$credentials_file"
        print_status "Cleaned up temporary credentials file"
    fi
    
    print_success "OADP credential copy process completed!"
    print_status "Next steps:"
    print_status "1. Monitor OADP deployment progress"
    print_status "2. Check DataProtectionApplication status"
    print_status "3. Test backup functionality"
    print_status "4. Configure backup schedules as needed"
}

# Run main function
main "$@"
