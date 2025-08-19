#!/bin/bash

# OADP Setup Script for OCP2 Cluster
# This script helps set up OADP with proper cloud credentials

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if oc command is available
check_oc() {
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed or not in PATH"
        exit 1
    fi
}

# Check cluster connection
check_cluster() {
    print_status "Checking cluster connection..."
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    CLUSTER_URL=$(oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    print_status "Connected to cluster: $CLUSTER_URL"
}

# Check if OADP operator is installed
check_oadp_operator() {
    print_status "Checking OADP operator status..."
    
    if oc get subscription redhat-oadp-operator -n openshift-adp &> /dev/null; then
        print_status "OADP operator subscription found"
        
        # Check operator status
        SUBSCRIPTION_STATUS=$(oc get subscription redhat-oadp-operator -n openshift-adp -o jsonpath='{.status.conditions[?(@.type=="InstallPlanFailed")].status}')
        if [ "$SUBSCRIPTION_STATUS" = "True" ]; then
            print_error "OADP operator installation failed. Check the subscription details:"
            oc describe subscription redhat-oadp-operator -n openshift-adp
            return 1
        fi
        
        # Check if CSV is installed
        if oc get csv -n openshift-adp | grep -q oadp; then
            print_status "OADP operator CSV is installed"
        else
            print_warning "OADP operator CSV not found yet. Installation may still be in progress."
        fi
    else
        print_error "OADP operator subscription not found. Check if ArgoCD has deployed the applications."
        return 1
    fi
}

# Check cloud credentials
check_cloud_credentials() {
    print_status "Checking cloud credentials..."
    
    if oc get secret cloud-credentials -n openshift-adp &> /dev/null; then
        print_status "Cloud credentials secret found"
        
        # Check if credentials are placeholder values
        ACCESS_KEY=$(oc get secret cloud-credentials -n openshift-adp -o jsonpath='{.data.cloud}' | base64 -d | grep aws_access_key_id | cut -d'=' -f2)
        if [ "$ACCESS_KEY" = "PLACEHOLDER_AWS_ACCESS_KEY_ID_REPLACE_ME" ]; then
            print_warning "Cloud credentials contain placeholder values. These need to be updated with real credentials."
            print_warning "Run the following command to copy real credentials from ocp-host cluster:"
            echo ""
            echo "  # Login to ocp-host cluster"
            echo "  oc login https://api.ocp-host.kohlerco.com:6443"
            echo "  oc get secret kohler-oadp-backups -n openshift-storage -o yaml | \\"
            echo "    sed 's/namespace: openshift-storage/namespace: openshift-adp/' | \\"
            echo "    oc apply -f -"
            echo ""
            return 1
        else
            print_status "Cloud credentials appear to be properly configured"
        fi
    else
        print_error "Cloud credentials secret not found. This is required for OADP to function."
        return 1
    fi
}

# Check data protection application
check_data_protection_app() {
    print_status "Checking data protection application..."
    
    if oc get dataprotectionapplication ocp2-velero-config -n openshift-adp &> /dev/null; then
        print_status "Data protection application found"
        
        # Check application status
        APP_STATUS=$(oc get dataprotectionapplication ocp2-velero-config -n openshift-adp -o jsonpath='{.status.conditions[?(@.type=="Reconciled")].status}')
        if [ "$APP_STATUS" = "True" ]; then
            print_status "Data protection application is reconciled"
        else
            print_warning "Data protection application is not yet reconciled. Check status:"
            oc describe dataprotectionapplication ocp2-velero-config -n openshift-adp
        fi
    else
        print_error "Data protection application not found. Check if ArgoCD has deployed the configuration."
        return 1
    fi
}

# Check Velero deployment
check_velero_deployment() {
    print_status "Checking Velero deployment..."
    
    if oc get deployment velero -n openshift-adp &> /dev/null; then
        print_status "Velero deployment found"
        
        # Check deployment status
        READY_REPLICAS=$(oc get deployment velero -n openshift-adp -o jsonpath='{.status.readyReplicas}')
        DESIRED_REPLICAS=$(oc get deployment velero -n openshift-adp -o jsonpath='{.spec.replicas}')
        
        if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ]; then
            print_status "Velero deployment is ready"
        else
            print_warning "Velero deployment is not ready. Ready: $READY_REPLICAS, Desired: $DESIRED_REPLICAS"
            
            # Check pod status
            oc get pods -n openshift-adp -l app.kubernetes.io/name=velero
        fi
    else
        print_warning "Velero deployment not found yet. This may be normal if OADP is still installing."
    fi
}

# Main execution
main() {
    print_status "Starting OADP setup verification for OCP2 cluster..."
    echo ""
    
    check_oc
    check_cluster
    echo ""
    
    print_status "Verifying OADP components..."
    echo ""
    
    # Check components in order
    check_oadp_operator
    echo ""
    
    check_cloud_credentials
    echo ""
    
    check_data_protection_app
    echo ""
    
    check_velero_deployment
    echo ""
    
    print_status "OADP setup verification completed!"
    print_status "If all checks pass, OADP should be working properly."
    print_status "If there are issues, check the ArgoCD application status and logs."
}

# Run main function
main "$@"
