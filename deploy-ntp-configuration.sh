#!/bin/bash
# NTP Configuration Deployment Script for OpenShift Cluster
# This script deploys NTP configurations to all node types (master, worker, infra, ODF, Quay)

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

print_status "Starting NTP configuration deployment..."

# Get current cluster info
CLUSTER_NAME=$(oc get clusterversion -o jsonpath='{.items[0].spec.clusterID}')
print_status "Deploying NTP configuration to cluster: $CLUSTER_NAME"

# Apply NTP configurations for all node types
NODE_TYPES=("master" "worker" "infra" "odf" "quay")

for node_type in "${NODE_TYPES[@]}"; do
    config_file="clusters/ocp2/99-${node_type}-chrony.yaml"

    if [[ -f "$config_file" ]]; then
        print_status "Applying NTP configuration for ${node_type} nodes..."
        if oc apply -f "$config_file"; then
            print_success "Successfully applied NTP config for ${node_type} nodes"
        else
            print_error "Failed to apply NTP config for ${node_type} nodes"
            exit 1
        fi
    else
        print_warning "NTP configuration file not found: $config_file"
    fi
done

print_status "Waiting for MachineConfigPool updates..."
sleep 10

# Check MachineConfigPool status
print_status "Checking MachineConfigPool status..."
oc get mcp

# Wait for configurations to be applied
print_status "Monitoring configuration rollout..."
for node_type in "${NODE_TYPES[@]}"; do
    if [[ "$node_type" != "odf" && "$node_type" != "quay" ]]; then
        print_status "Checking ${node_type} MachineConfigPool..."
        oc wait --for=condition=Updated mcp/${node_type} --timeout=300s || {
            print_warning "${node_type} MachineConfigPool update timeout - check status manually"
        }
    fi
done

print_success "NTP configuration deployment completed!"
print_status "All cluster nodes should now have NTP configured with timehost.kohlerco.com"

# Verification steps
print_status "Verification commands:"
echo "  - Check chrony status on nodes: oc debug node/<node-name> -- chroot /host chronyc tracking"
echo "  - Check MachineConfig status: oc get mcp"
echo "  - View NTP config on nodes: oc debug node/<node-name> -- chroot /host cat /etc/chrony.conf"

exit 0
