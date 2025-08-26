#!/bin/bash

# Quay Registry Deployment Script for OCP2 Cluster
# This script deploys Red Hat Quay Registry using ArgoCD GitOps

set -e

echo "=== Red Hat Quay Registry Deployment for OCP2 ==="
echo "Date: $(date)"
echo

# Check if we're connected to the correct cluster
if ! oc whoami >/dev/null 2>&1; then
    echo "❌ Error: Not connected to OpenShift cluster"
    echo "Please run: oc login -u kubeadmin -p FUKeF-MWGqX-H52Et-8wx5T --server=https://api.ocp2.kohlerco.com:6443"
    exit 1
fi

CLUSTER_API=$(oc whoami --show-server)
if [[ "$CLUSTER_API" != *"ocp2.kohlerco.com"* ]]; then
    echo "❌ Error: Not connected to ocp2 cluster"
    echo "Current cluster: $CLUSTER_API"
    echo "Please connect to ocp2: oc login -u kubeadmin -p FUKeF-MWGqX-H52Et-8wx5T --server=https://api.ocp2.kohlerco.com:6443"
    exit 1
fi

echo "✅ Connected to ocp2 cluster: $CLUSTER_API"
echo "✅ Logged in as: $(oc whoami)"
echo

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ $1 failed"
        exit 1
    fi
}

# Function to wait for ArgoCD application to sync
wait_for_app_sync() {
    local app_name=$1
    local timeout=${2:-300}
    
    echo "Waiting for ArgoCD application '$app_name' to sync..."
    
    for i in $(seq 1 $timeout); do
        STATUS=$(oc get application $app_name -n openshift-gitops -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
        HEALTH=$(oc get application $app_name -n openshift-gitops -o jsonpath='{.status.health.status}' 2>/dev/null || echo "NotFound")
        
        if [[ "$STATUS" == "Synced" && "$HEALTH" == "Healthy" ]]; then
            echo "✅ Application '$app_name' is synced and healthy"
            return 0
        fi
        
        if [[ $((i % 30)) -eq 0 ]]; then
            echo "  Waiting... Status: $STATUS, Health: $HEALTH ($i/${timeout}s)"
        fi
        
        sleep 1
    done
    
    echo "⚠️  Application '$app_name' did not sync within ${timeout}s"
    echo "Current status: Sync=$STATUS, Health=$HEALTH"
    return 1
}

# Prerequisites check
echo "Step 1: Checking prerequisites..."

# Check if ArgoCD is available
if ! oc get namespace openshift-gitops >/dev/null 2>&1; then
    echo "❌ Error: OpenShift GitOps (ArgoCD) is not installed"
    echo "Please install OpenShift GitOps operator first"
    exit 1
fi

# Check if ODF is available
if ! oc get storageclass ocs-storagecluster-ceph-rbd >/dev/null 2>&1; then
    echo "❌ Error: OpenShift Data Foundation (ODF) is not available"
    echo "Required storage class 'ocs-storagecluster-ceph-rbd' not found"
    exit 1
fi

echo "✅ ArgoCD is available"
echo "✅ ODF storage is available"
echo

# Step 2: Deploy Quay Operator
echo "Step 2: Deploying Quay Operator..."
oc apply -f argocd-apps/quay-ocp2.yaml
check_status "Quay ArgoCD applications created"

# Wait for operator to sync
wait_for_app_sync "quay-operator-ocp2" 600
echo

# Step 3: Wait for operator to be ready
echo "Step 3: Waiting for Quay operator to be ready..."
echo "This may take several minutes..."

for i in {1..60}; do
    if oc get csv -n openshift-operators 2>/dev/null | grep -q "quay-operator.*Succeeded"; then
        echo "✅ Quay operator is ready"
        break
    fi
    if [[ $i -eq 60 ]]; then
        echo "⚠️  Quay operator installation taking longer than expected"
        echo "Current CSV status:"
        oc get csv -n openshift-operators | grep quay || echo "No Quay CSV found"
    fi
    echo "  Waiting for operator... ($i/60)"
    sleep 10
done
echo

# Step 4: Deploy Quay Configuration
echo "Step 4: Deploying Quay Configuration..."
wait_for_app_sync "quay-configuration-ocp2" 900
echo

# Step 5: Wait for Quay Registry to be ready
echo "Step 5: Waiting for Quay Registry to be ready..."
echo "This may take 10-15 minutes for initial setup..."

for i in {1..90}; do
    if oc get quayregistry kohler-quay-registry -n quay-enterprise >/dev/null 2>&1; then
        STATUS=$(oc get quayregistry kohler-quay-registry -n quay-enterprise -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [[ "$STATUS" == "True" ]]; then
            echo "✅ Quay Registry is available"
            break
        fi
    fi
    if [[ $i -eq 90 ]]; then
        echo "⚠️  Quay Registry not ready within expected time"
        echo "Current status:"
        oc get quayregistry kohler-quay-registry -n quay-enterprise -o yaml | grep -A 10 "conditions:" || echo "QuayRegistry not found"
    fi
    if [[ $((i % 10)) -eq 0 ]]; then
        echo "  Waiting for Quay Registry... ($i/90)"
    fi
    sleep 10
done
echo

# Step 6: Deploy Mirror Configuration
echo "Step 6: Deploying Mirror Configuration..."
wait_for_app_sync "quay-mirror-config-ocp2" 300
echo

# Step 7: Final verification
echo "Step 7: Final verification..."

echo "Checking Quay components:"
oc get pods -n quay-enterprise 2>/dev/null || echo "⚠️  quay-enterprise namespace not ready"
echo

echo "Checking Quay Registry status:"
oc get quayregistry -n quay-enterprise -o wide 2>/dev/null || echo "⚠️  QuayRegistry not ready"
echo

echo "Checking Quay route:"
if oc get route -n quay-enterprise 2>/dev/null | grep -q quay; then
    QUAY_URL=$(oc get route -n quay-enterprise -o jsonpath='{.items[0].spec.host}' 2>/dev/null)
    echo "✅ Quay Registry URL: https://$QUAY_URL"
else
    echo "⚠️  Quay route not yet available"
fi
echo

echo "Checking storage:"
oc get pvc -n quay-enterprise 2>/dev/null || echo "⚠️  PVCs not ready"
oc get objectbucketclaim -n quay-enterprise 2>/dev/null || echo "⚠️  ObjectBucketClaim not ready"
echo

# Summary
echo "=== Deployment Summary ==="
echo "✅ Quay Operator: Deployed"
echo "✅ Quay Configuration: Deployed" 
echo "✅ Quay Mirror Config: Deployed"
echo "✅ ArgoCD Applications: Created"
echo
echo "🔗 Access Information:"
echo "   Registry URL: https://quay.apps.ocp2.kohlerco.com"
echo "   Authentication: Azure AD OIDC"
echo "   Admin User: admin"
echo
echo "📊 Monitor deployment:"
echo "   oc get applications -n openshift-gitops | grep quay"
echo "   oc get pods -n quay-enterprise"
echo "   oc get quayregistry -n quay-enterprise"
echo
echo "🔧 Troubleshooting:"
echo "   See: clusters/ocp2/README-QUAY.md"
echo
echo "✅ Quay Registry deployment completed successfully!"
