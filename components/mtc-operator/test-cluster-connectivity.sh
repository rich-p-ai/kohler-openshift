#!/bin/bash

# Test Cluster Connectivity Script
# This script tests basic connectivity to both clusters before running MTC setup

set -e

echo "🔍 Testing Cluster Connectivity"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Test ocp-prd connectivity
test_ocp_prd() {
    print_status "Testing ocp-prd connectivity..."
    
    # Test basic connectivity
    if curl -k -s --connect-timeout 10 https://api.ocp-prd.kohlerco.com:6443/healthz > /dev/null 2>&1; then
        print_success "ocp-prd API endpoint is reachable"
    else
        print_error "ocp-prd API endpoint is not reachable"
        return 1
    fi
    
    # Test login
    print_status "Testing ocp-prd login..."
    if oc login -u kubeadmin -p KUHNz-u7GkB-rZFdo-u6FVV --server=https://api.ocp-prd.kohlerco.com:6443 --insecure-skip-tls-verify --request-timeout=30s > /dev/null 2>&1; then
        print_success "ocp-prd login successful"
        
        # Test basic cluster access
        if oc get nodes > /dev/null 2>&1; then
            print_success "ocp-prd cluster access confirmed"
            oc get nodes --no-headers | wc -l | xargs -I {} echo "Number of nodes: {}"
        else
            print_warning "ocp-prd login successful but cluster access failed"
        fi
    else
        print_error "ocp-prd login failed"
        return 1
    fi
}

# Test ocp2 connectivity
test_ocp2() {
    print_status "Testing ocp2 connectivity..."
    
    # Test basic connectivity
    if curl -k -s --connect-timeout 10 https://api.ocp2.kohlerco.com:6443/healthz > /dev/null 2>&1; then
        print_success "ocp2 API endpoint is reachable"
    else
        print_error "ocp2 API endpoint is not reachable"
        return 1
    fi
    
    # Test login
    print_status "Testing ocp2 login..."
    if oc login -u kubeadmin -p FUKeF-MWGqX-H52Et-8wx5T --server=https://api.ocp2.kohlerco.com:6443 --insecure-skip-tls-verify --request-timeout=30s > /dev/null 2>&1; then
        print_success "ocp2 login successful"
        
        # Test basic cluster access
        if oc get nodes > /dev/null 2>&1; then
            print_success "ocp2 cluster access confirmed"
            oc get nodes --no-headers | wc -l | xargs -I {} echo "Number of nodes: {}"
        else
            print_warning "ocp2 login successful but cluster access failed"
        fi
    else
        print_error "ocp2 login failed"
        return 1
    fi
}

# Main execution
main() {
    echo "Testing connectivity to both clusters..."
    echo ""
    
    # Test ocp-prd
    if test_ocp_prd; then
        print_success "ocp-prd connectivity test PASSED"
    else
        print_error "ocp-prd connectivity test FAILED"
    fi
    
    echo ""
    
    # Test ocp2
    if test_ocp2; then
        print_success "ocp2 connectivity test PASSED"
    else
        print_error "ocp2 connectivity test FAILED"
    fi
    
    echo ""
    echo "=========================================="
    echo "Connectivity Test Complete"
    echo "=========================================="
    echo ""
    echo "If both tests passed, you can run: ./setup-mtc.sh"
    echo "If tests failed, check network connectivity and cluster status"
}

# Run main function
main "$@"
