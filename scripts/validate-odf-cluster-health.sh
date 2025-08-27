#!/bin/bash
# ODF Cluster Health Validation Script
# Comprehensive health check for Ceph cluster after resource profile fix

set -e

echo "=== ODF Cluster Health Validation ==="

# Check StorageCluster status
echo "1. Checking StorageCluster status..."
oc get storagecluster ocs-storagecluster -n openshift-storage -o wide
echo ""

# Check CephCluster status
echo "2. Checking CephCluster status..."
oc get cephcluster ocs-storagecluster-cephcluster -n openshift-storage -o wide
echo ""

# Check monitor pods
echo "3. Checking Ceph monitor pods..."
oc get pods -l app=rook-ceph-mon -n openshift-storage
echo ""

# Check OSD pods
echo "4. Checking OSD pods..."
oc get pods -l app=rook-ceph-osd -n openshift-storage
echo ""

# Check NooBaa pods
echo "5. Checking NooBaa pods..."
oc get pods -l app=noobaa -n openshift-storage
echo ""

# Check CSI driver pods
echo "6. Checking CSI driver pods..."
oc get pods -l app=csi-cephfsplugin -n openshift-storage
oc get pods -l app=csi-rbdplugin -n openshift-storage
echo ""

# Check storage classes
echo "7. Checking storage classes..."
oc get storageclass | grep -E "(ceph|rbd|fs)"
echo ""

# Check PVCs
echo "8. Checking persistent volume claims..."
oc get pvc --all-namespaces | grep -v Bound | head -10 || echo "All PVCs are bound"
echo ""

# Check nodes with storage labels
echo "9. Checking storage nodes..."
oc get nodes -l cluster.ocs.openshift.io/openshift-storage
echo ""

# Summary and recommendations
echo "=== Health Check Summary ==="

# Count healthy components
monitors_running=$(oc get pods -l app=rook-ceph-mon -n openshift-storage -o jsonpath='{.items[*].status.phase}' | grep -o 'Running' | wc -l)
osd_running=$(oc get pods -l app=rook-ceph-osd -n openshift-storage -o jsonpath='{.items[*].status.phase}' | grep -o 'Running' | wc -l)
csi_running=$(oc get pods -l 'app in (csi-cephfsplugin,csi-rbdplugin)' -n openshift-storage -o jsonpath='{.items[*].status.phase}' | grep -o 'Running' | wc -l)

echo "✅ Monitors running: $monitors_running/3"
echo "✅ OSD pods running: $osd_running"
echo "✅ CSI pods running: $csi_running"

# Check for issues
if [ "$monitors_running" -lt 3 ]; then
    echo "❌ WARNING: Not all monitors are running. Quorum may be at risk."
fi

if [ "$osd_running" -eq 0 ]; then
    echo "❌ CRITICAL: No OSD pods are running. Storage is unavailable."
fi

if [ "$csi_running" -eq 0 ]; then
    echo "❌ CRITICAL: No CSI drivers are running. Storage provisioning will fail."
fi

echo ""
echo "=== Recommendations ==="
echo "• Monitor cluster health with: oc get cephcluster -n openshift-storage -w"
echo "• Check Ceph status with: oc rsh -n openshift-storage <toolbox-pod> ceph status"
echo "• Validate storage provisioning by creating a test PVC"
echo "• Run regular health checks with this script"

echo ""
echo "Health validation complete."
