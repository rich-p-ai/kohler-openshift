#!/bin/bash
# Emergency Monitor Stabilization Script
# This script temporarily stabilizes the Ceph cluster by ensuring monitor quorum

set -e

echo "=== Emergency Monitor Stabilization ==="
echo "This script will temporarily stabilize the Ceph monitors to achieve quorum"

# Check current monitor status
echo "Current monitor pods:"
oc get pods -l app=rook-ceph-mon -n openshift-storage

# Scale down problematic monitors to allow stabilization
echo "Temporarily scaling down monitor deployments to stabilize..."
oc scale deployment rook-ceph-mon-a -n openshift-storage --replicas=0
oc scale deployment rook-ceph-mon-b -n openshift-storage --replicas=0

echo "Waiting for monitor-d to stabilize..."
sleep 30

# Check if monitor-d is healthy
echo "Checking monitor-d health..."
MON_D_READY=$(oc get pods -l app=rook-ceph-mon -n openshift-storage -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')

if [[ "$MON_D_READY" == "True" ]]; then
    echo "✅ Monitor-d is healthy. Waiting for cluster stabilization..."
    sleep 60

    # Now try to bring back one additional monitor
    echo "Bringing back monitor-a..."
    oc scale deployment rook-ceph-mon-a -n openshift-storage --replicas=1

    echo "Waiting for monitor-a to join..."
    sleep 60

    # Check if we now have quorum
    MON_COUNT=$(oc get pods -l app=rook-ceph-mon -n openshift-storage -o jsonpath='{.items[*].status.phase}' | grep -o 'Running' | wc -l)

    if [[ "$MON_COUNT" -ge 2 ]]; then
        echo "✅ Monitor quorum achieved! Bringing back monitor-b..."
        oc scale deployment rook-ceph-mon-b -n openshift-storage --replicas=1
    else
        echo "⚠️  Monitor quorum not yet stable. Keeping single monitor configuration."
    fi
else
    echo "❌ Monitor-d is not healthy. Check cluster status manually."
    exit 1
fi

echo "Monitor stabilization complete. Check cluster health:"
echo "  oc get cephcluster -n openshift-storage"
echo "  oc get pods -l app=rook-ceph-mon -n openshift-storage"
