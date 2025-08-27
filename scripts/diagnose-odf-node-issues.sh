#!/bin/bash
# ODF Node Scheduling Diagnostics
# This script helps identify node labeling and tainting issues that prevent Ceph monitor scheduling

set -e

echo "=== ODF Node Scheduling Diagnostics ==="
echo "This script identifies issues preventing Ceph monitor pods from scheduling"
echo ""

# Check storage nodes
echo "1. Storage nodes with required labels:"
echo "Nodes with cluster.ocs.openshift.io/openshift-storage label:"
oc get nodes -l cluster.ocs.openshift.io/openshift-storage -o wide
echo ""

echo "Nodes with node-role.kubernetes.io/infra label:"
oc get nodes -l node-role.kubernetes.io/infra -o wide
echo ""

# Check node taints
echo "2. Node taints that may block scheduling:"
oc get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints' | grep -E "(infra|storage)"
echo ""

# Check current monitor pod status
echo "3. Current monitor pod scheduling status:"
oc get pods -l app=rook-ceph-mon -n openshift-storage -o wide
echo ""

# Check pending pods events
echo "4. Recent events for pending monitor pods:"
for pod in $(oc get pods -l app=rook-ceph-mon -n openshift-storage -o jsonpath='{.items[*].metadata.name}'); do
    if [[ "$pod" == *"Pending"* ]] || [[ "$pod" != *"Running"* ]]; then
        echo "Events for pod $pod:"
        oc describe pod $pod -n openshift-storage | grep -A 10 -B 2 "Warning\|Error\|Failed"
        echo ""
    fi
done

# Check storage cluster placement configuration
echo "5. Current StorageCluster placement configuration:"
oc get storagecluster ocs-storagecluster -n openshift-storage -o yaml | grep -A 20 "placement:"
echo ""

echo "=== Diagnostics Complete ==="
echo ""
echo "Common solutions:"
echo "• Ensure nodes have the cluster.ocs.openshift.io/openshift-storage label"
echo "• Ensure nodes have the node-role.kubernetes.io/infra label (for mon placement)"
echo "• Check that tolerations match the node taints"
echo "• Verify node resources are sufficient"
echo ""
echo "Run the emergency fix script if scheduling issues persist:"
echo "  ./emergency-odf-resource-profile-fix.sh"
