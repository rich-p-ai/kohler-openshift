#!/bin/bash

# Script to copy OADP cloud credentials from ocp-host cluster to ocp-prd cluster
# This resolves the "AWS access key Id you provided does not exist" error

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

print_section() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Configuration
OCP_HOST_URL="https://api.ocp-host.kohlerco.com:6443"
OCP_PRD_URL="https://api.ocp-prd.kohlerco.com:6443"
NAMESPACE="openshift-adp"
SECRET_NAME="cloud-credentials"

print_section "OADP CREDENTIALS COPY SCRIPT"
print_info "This script copies OADP cloud credentials from ocp-host to ocp-prd cluster"
print_info "This resolves the 'AWS access key Id you provided does not exist' error"
echo ""

# Check if oc command is available
if ! command -v oc &> /dev/null; then
    print_error "OpenShift CLI (oc) is not installed or not in PATH"
    exit 1
fi

# Step 1: Login to ocp-host cluster
print_section "STEP 1: LOGIN TO OCP-HOST CLUSTER"
print_info "Please login to the ocp-host cluster..."
print_info "Cluster URL: $OCP_HOST_URL"
echo ""

if ! oc login "$OCP_HOST_URL" --insecure-skip-tls-verify; then
    print_error "Failed to login to ocp-host cluster"
    exit 1
fi

print_success "Successfully logged into ocp-host cluster"

# Step 2: Verify the secret exists on ocp-host
print_section "STEP 2: VERIFY CREDENTIALS ON OCP-HOST"
if ! oc get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    print_error "Secret '$SECRET_NAME' not found in namespace '$NAMESPACE' on ocp-host"
    print_info "Available secrets in $NAMESPACE:"
    oc get secrets -n "$NAMESPACE" --no-headers || true
    exit 1
fi

print_success "Found secret '$SECRET_NAME' on ocp-host cluster"

# Step 3: Export the secret
print_section "STEP 3: EXPORT CREDENTIALS FROM OCP-HOST"
TEMP_SECRET_FILE="/tmp/ocp-host-cloud-credentials.yaml"

if oc get secret "$SECRET_NAME" -n "$NAMESPACE" -o yaml > "$TEMP_SECRET_FILE"; then
    print_success "Credentials exported to $TEMP_SECRET_FILE"
else
    print_error "Failed to export credentials from ocp-host"
    exit 1
fi

# Step 4: Login to ocp-prd cluster
print_section "STEP 4: LOGIN TO OCP-PRD CLUSTER"
print_info "Please login to the ocp-prd cluster..."
print_info "Cluster URL: $OCP_PRD_URL"
echo ""

if ! oc login "$OCP_PRD_URL" --insecure-skip-tls-verify; then
    print_error "Failed to login to ocp-prd cluster"
    exit 1
fi

print_success "Successfully logged into ocp-prd cluster"

# Step 5: Create namespace if it doesn't exist
print_section "STEP 5: CREATE OADP NAMESPACE ON OCP-PRD"
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    print_info "Creating namespace '$NAMESPACE' on ocp-prd..."
    if oc create namespace "$NAMESPACE"; then
        print_success "Namespace '$NAMESPACE' created on ocp-prd"
    else
        print_error "Failed to create namespace '$NAMESPACE'"
        exit 1
    fi
else
    print_info "Namespace '$NAMESPACE' already exists on ocp-prd"
fi

# Step 6: Apply the secret to ocp-prd
print_section "STEP 6: APPLY CREDENTIALS TO OCP-PRD"
print_info "Applying cloud credentials to ocp-prd cluster..."

if oc apply -f "$TEMP_SECRET_FILE"; then
    print_success "Cloud credentials successfully applied to ocp-prd cluster"
else
    print_error "Failed to apply cloud credentials to ocp-prd cluster"
    exit 1
fi

# Step 7: Verify the secret was created
print_section "STEP 7: VERIFY CREDENTIALS ON OCP-PRD"
if oc get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    print_success "Secret '$SECRET_NAME' verified on ocp-prd cluster"
else
    print_error "Secret '$SECRET_NAME' not found on ocp-prd cluster after creation"
    exit 1
fi

# Step 8: Cleanup
print_section "STEP 8: CLEANUP"
rm -f "$TEMP_SECRET_FILE"
print_success "Temporary files cleaned up"

# Step 9: Next steps
print_section "NEXT STEPS"
print_success "OADP cloud credentials have been successfully copied to ocp-prd cluster!"
echo ""
print_info "To complete the OADP setup:"
echo "1. Verify the DataProtectionApplication is using the correct configuration:"
echo "   oc get dpa -n openshift-adp"
echo ""
echo "2. Check that the backup location is properly configured:"
echo "   oc get backupstoragelocations -n openshift-adp"
echo ""
echo "3. Test a backup to verify the credentials work:"
echo "   oc create -f examples/backup-example.yaml"
echo ""
print_info "The OADP configuration should now work with the S3 storage on ocp-host cluster"
print_info "S3 Endpoint: https://s3.openshift-storage.svc:443"
print_info "Bucket: kohler-oadp-backups-ec378362-ab9d-433a-bd1a-87af6e630eba"
