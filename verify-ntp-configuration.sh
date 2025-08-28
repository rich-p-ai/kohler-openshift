#!/bin/bash
# NTP Configuration Verification Script for OpenShift Cluster
# This script verifies NTP configuration on all cluster nodes

set -e

# Color codes for output
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

# Check if we're running on OpenShift
if ! oc whoami >/dev/null 2>&1; then
    print_error "Not logged into OpenShift cluster. Please login first with 'oc login'"
    exit 1
fi

print_status "Starting NTP configuration verification..."

# Get all nodes
NODES=$(oc get nodes -o jsonpath='{.items[*].metadata.name}')
NODE_COUNT=$(echo "$NODES" | wc -w)

print_status "Found $NODE_COUNT nodes in the cluster"

# Check MachineConfig status
print_status "Checking MachineConfig status..."
echo "MachineConfigPool Status:"
oc get mcp -o custom-columns=NAME:.metadata.name,CONFIG:.status.configuration.name,UPDATED:.status.conditions[?(@.type=="Updated")].status,UPDATING:.status.conditions[?(@.type=="Updating")].status
echo ""

# Check NTP configuration on each node
print_status "Checking NTP configuration on each node..."

for node in $NODES; do
    echo "----------------------------------------"
    echo "Node: $node"

    # Get node labels to determine node type
    NODE_LABELS=$(oc get node $node -o jsonpath='{.metadata.labels}')
    NODE_TYPE="unknown"

    if echo "$NODE_LABELS" | grep -q "node-role.kubernetes.io/master"; then
        NODE_TYPE="master"
    elif echo "$NODE_LABELS" | grep -q "node-role.kubernetes.io/infra"; then
        NODE_TYPE="infra"
    elif echo "$NODE_LABELS" | grep -q "cluster.ocs.openshift.io/openshift-storage"; then
        NODE_TYPE="odf"
    elif echo "$NODE_LABELS" | grep -q "node-role.kubernetes.io/worker"; then
        NODE_TYPE="worker"
    fi

    echo "Node Type: $NODE_TYPE"

    # Check if chrony config exists
    if oc debug node/$node -- chroot /host cat /etc/chrony.conf >/dev/null 2>&1; then
        echo "✓ NTP Configuration found"

        # Check chrony configuration content
        CHRONY_CONFIG=$(oc debug node/$node -- chroot /host cat /etc/chrony.conf 2>/dev/null)

        if echo "$CHRONY_CONFIG" | grep -q "timehost.kohlerco.com"; then
            print_success "  ✓ Correct NTP server configured: timehost.kohlerco.com"
        else
            print_warning "  ⚠ NTP server configuration may be incorrect"
            echo "  Current config:"
            echo "$CHRONY_CONFIG" | head -5
        fi

        # Check chrony service status
        if oc debug node/$node -- chroot /host systemctl is-active chronyd >/dev/null 2>&1; then
            print_success "  ✓ Chrony service is active"
        else
            print_error "  ✗ Chrony service is not active"
        fi

        # Check NTP synchronization status
        if oc debug node/$node -- chroot /host chronyc tracking >/dev/null 2>&1; then
            TRACKING_INFO=$(oc debug node/$node -- chroot /host chronyc tracking 2>/dev/null)
            if echo "$TRACKING_INFO" | grep -q "Reference ID"; then
                print_success "  ✓ NTP synchronization active"
            else
                print_warning "  ⚠ NTP synchronization status unclear"
            fi
        else
            print_warning "  ⚠ Could not check NTP tracking status"
        fi

    else
        print_error "  ✗ NTP configuration not found on node"
    fi

    echo ""
done

# Summary
echo "========================================="
print_status "NTP Configuration Verification Summary"
echo "========================================="

# Check MachineConfigs
echo "MachineConfig Status:"
for node_type in master worker infra; do
    if oc get mc 99-${node_type}-chrony >/dev/null 2>&1; then
        print_success "✓ 99-${node_type}-chrony MachineConfig exists"
    else
        print_error "✗ 99-${node_type}-chrony MachineConfig missing"
    fi
done

# Check for custom node roles (ODF, Quay)
ODF_NODES=$(oc get nodes -l cluster.ocs.openshift.io/openshift-storage= -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$ODF_NODES" ]]; then
    if oc get mc 99-odf-chrony >/dev/null 2>&1; then
        print_success "✓ 99-odf-chrony MachineConfig exists for ODF nodes"
    else
        print_warning "⚠ 99-odf-chrony MachineConfig missing (ODF nodes detected)"
    fi
fi

print_status "Verification completed!"
print_status "For detailed NTP status on any node, run:"
echo "  oc debug node/<node-name> -- chroot /host chronyc tracking"
echo "  oc debug node/<node-name> -- chroot /host chronyc sources"

exit 0
