#!/bin/bash
# Rook Ceph Tools Deployment Verification Script
# This script verifies that the rook-ceph-tools deployment is working correctly

set -e

NAMESPACE="openshift-storage"
DEPLOYMENT_NAME="rook-ceph-tools"

echo "🔍 Verifying Rook Ceph Tools Deployment"
echo "========================================"

# Function to check pod status
check_pod_status() {
    echo "📦 Checking pod status..."
    local pod_status=$(oc get pods -n $NAMESPACE -l app=rook-ceph-tools -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")

    if [ "$pod_status" = "Running" ]; then
        echo "✅ Pod is running"
        return 0
    elif [ "$pod_status" = "NotFound" ]; then
        echo "❌ Pod not found - deployment may not be created yet"
        return 1
    else
        echo "⚠️  Pod status: $pod_status"
        return 2
    fi
}

# Function to check service account
check_service_account() {
    echo "🔐 Checking service account..."
    if oc get serviceaccount rook-ceph-tools -n $NAMESPACE >/dev/null 2>&1; then
        echo "✅ Service account exists"
        return 0
    else
        echo "❌ Service account not found"
        return 1
    fi
}

# Function to check RBAC
check_rbac() {
    echo "🔒 Checking RBAC..."
    local rbac_ok=true

    if ! oc get clusterrole rook-ceph-tools-cluster-role >/dev/null 2>&1; then
        echo "❌ ClusterRole not found"
        rbac_ok=false
    else
        echo "✅ ClusterRole exists"
    fi

    if ! oc get clusterrolebinding rook-ceph-tools-cluster-role-binding >/dev/null 2>&1; then
        echo "❌ ClusterRoleBinding not found"
        rbac_ok=false
    else
        echo "✅ ClusterRoleBinding exists"
    fi

    if $rbac_ok; then
        return 0
    else
        return 1
    fi
}

# Function to check Ceph connectivity
check_ceph_connectivity() {
    echo "🔗 Checking Ceph connectivity..."
    local pod_name=$(oc get pods -n $NAMESPACE -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$pod_name" ]; then
        echo "❌ Cannot find pod for connectivity test"
        return 1
    fi

    # Test basic Ceph commands
    echo "Testing Ceph commands..."
    if oc exec $pod_name -n $NAMESPACE -- ceph status >/dev/null 2>&1; then
        echo "✅ Ceph status command successful"
        return 0
    else
        echo "❌ Ceph status command failed"
        echo "   This might be expected if Ceph cluster is not healthy"
        echo "   Check Ceph cluster status: oc get cephcluster -n $NAMESPACE"
        return 2
    fi
}

# Function to show usage instructions
show_usage() {
    echo ""
    echo "📖 Usage Instructions:"
    echo "======================"
    echo "To access the Rook Ceph Tools:"
    echo ""
    echo "1. Get the pod name:"
    echo "   oc get pods -n $NAMESPACE -l app=rook-ceph-tools"
    echo ""
    echo "2. Exec into the pod:"
    echo "   oc rsh -n $NAMESPACE deployment/$DEPLOYMENT_NAME"
    echo ""
    echo "3. Run Ceph commands:"
    echo "   ceph status"
    echo "   ceph df"
    echo "   ceph osd tree"
    echo "   ceph pg stat"
    echo ""
    echo "4. For RADOS Gateway operations:"
    echo "   radosgw-admin bucket list"
    echo ""
    echo "5. For RBD operations:"
    echo "   rbd list"
}

# Main verification
echo "Namespace: $NAMESPACE"
echo "Deployment: $DEPLOYMENT_NAME"
echo ""

# Run checks
check_service_account
check_rbac
check_pod_status

# Only check Ceph connectivity if pod is running
if check_pod_status >/dev/null 2>&1; then
    check_ceph_connectivity
fi

show_usage

echo ""
echo "🎉 Verification complete!"
echo ""
echo "If you encounter issues:"
echo "- Check ArgoCD application status"
echo "- Verify Ceph cluster is healthy: oc get cephcluster -n $NAMESPACE"
echo "- Check deployment logs: oc logs deployment/$DEPLOYMENT_NAME -n $NAMESPACE"
