#!/bin/bash

# Catalog Source Troubleshooting Script for OADP Operator
# This script helps diagnose and fix catalog source issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
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

# Check catalog sources
check_catalog_sources() {
    print_header "Checking Catalog Sources Status"
    echo ""
    
    print_status "Listing all catalog sources in openshift-marketplace namespace..."
    oc get catalogsources -n openshift-marketplace
    
    echo ""
    print_status "Checking redhat-operators catalog source specifically..."
    if oc get catalogsource redhat-operators -n openshift-marketplace &> /dev/null; then
        print_status "redhat-operators catalog source found"
        
        # Check status
        STATUS=$(oc get catalogsource redhat-operators -n openshift-marketplace -o jsonpath='{.status.connectionState.lastObservedState}')
        print_status "Connection state: $STATUS"
        
        # Check if pods are running
        print_status "Checking catalog source pods..."
        oc get pods -n openshift-marketplace -l olm.catalogSource=redhat-operators
        
        # Check logs if there are issues
        if [ "$STATUS" != "READY" ]; then
            print_warning "Catalog source is not ready. Checking logs..."
            oc logs -n openshift-marketplace -l olm.catalogSource=redhat-operators --tail=50
        fi
    else
        print_error "redhat-operators catalog source not found!"
        print_status "Creating catalog source..."
        create_catalog_source
    fi
}

# Create catalog source if missing
create_catalog_source() {
    print_status "Creating redhat-operators catalog source..."
    
    cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhat-operators
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.redhat.io/redhat/redhat-operator-index:v4.15
  displayName: Red Hat Operators
  publisher: Red Hat
  updateStrategy:
    registryPoll:
      interval: 10m
  grpcPodConfig:
    securityContextConfig: restricted
EOF
    
    print_status "Waiting for catalog source to be ready..."
    sleep 30
    
    # Check status again
    check_catalog_sources
}

# Check operator subscriptions
check_subscriptions() {
    print_header "Checking Operator Subscriptions"
    echo ""
    
    print_status "Checking OADP operator subscription..."
    if oc get subscription redhat-oadp-operator -n openshift-adp &> /dev/null; then
        print_status "OADP operator subscription found"
        
        # Check subscription status
        oc describe subscription redhat-oadp-operator -n openshift-adp
        
        # Check install plans
        print_status "Checking install plans..."
        oc get installplans -n openshift-adp
        
        # Check CSV status
        print_status "Checking CSV status..."
        oc get csv -n openshift-adp
    else
        print_error "OADP operator subscription not found!"
    fi
}

# Check network connectivity
check_network() {
    print_header "Checking Network Connectivity"
    echo ""
    
    print_status "Testing connectivity to Red Hat registry..."
    
    # Check if we can reach the registry
    if oc debug node/$(oc get nodes -o jsonpath='{.items[0].metadata.name}') -- chroot /host curl -k -s -o /dev/null -w "%{http_code}" https://registry.redhat.io/v2/ &> /dev/null; then
        print_status "Successfully connected to Red Hat registry"
    else
        print_warning "Cannot connect to Red Hat registry. This may indicate network restrictions."
        print_warning "Consider using a mirror registry or air-gapped installation."
    fi
    
    # Check cluster-wide proxy settings
    print_status "Checking cluster-wide proxy configuration..."
    oc get proxy cluster -o yaml
}

# Check marketplace operator
check_marketplace() {
    print_header "Checking Marketplace Operator"
    echo ""
    
    print_status "Checking if marketplace operator is running..."
    if oc get deployment marketplace-operator -n openshift-marketplace &> /dev/null; then
        print_status "Marketplace operator deployment found"
        oc get deployment marketplace-operator -n openshift-marketplace
        
        # Check pods
        print_status "Checking marketplace operator pods..."
        oc get pods -n openshift-marketplace -l name=marketplace-operator
    else
        print_warning "Marketplace operator not found. This may be normal in some OpenShift versions."
    fi
}

# Provide remediation steps
provide_remediation() {
    print_header "Remediation Steps"
    echo ""
    
    print_status "If catalog source issues persist, try these steps:"
    echo ""
    echo "1. Check network policies and firewall rules"
    echo "2. Verify cluster-wide proxy configuration"
    echo "3. Ensure Red Hat registry credentials are configured"
    echo "4. Consider using a mirror registry for air-gapped environments"
    echo "5. Check if the cluster has internet access"
    echo ""
    echo "For immediate fix, you can manually create the catalog source:"
    echo "oc apply -f components/oadp-operator/catalog-source.yaml"
    echo ""
    echo "Or use the manual OADP installation:"
    echo "oc apply -f ocp2-oadp-setup/"
}

# Main execution
main() {
    print_header "OADP Operator Catalog Source Troubleshooting"
    echo ""
    
    check_oc
    check_cluster
    echo ""
    
    check_catalog_sources
    echo ""
    
    check_subscriptions
    echo ""
    
    check_network
    echo ""
    
    check_marketplace
    echo ""
    
    provide_remediation
    echo ""
    
    print_status "Troubleshooting completed!"
}

# Run main function
main "$@"
