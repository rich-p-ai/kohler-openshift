#!/bin/bash

# ODF Deployment Script for OpenShift Clusters
# This script deploys ODF using the configurations from this git repository

set -e

echo "=== OpenShift Data Foundation (ODF) Deployment Script ==="
echo "Date: $(date)"
echo

# Check if we're connected to a cluster
if ! oc whoami >/dev/null 2>&1; then
    echo "❌ Error: Not connected to OpenShift cluster"
    echo "Please run 'oc login' first"
    exit 1
fi

CLUSTER_NAME=$(oc config view --minify -o jsonpath='{.clusters[0].name}')
echo "Connected to cluster: $CLUSTER_NAME"
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

# Step 1: Deploy ODF Operator
echo "Step 1: Deploying ODF Operator..."
oc kustomize kohler-openshift/components/odf-operator | oc apply -f -
check_status "ODF Operator deployment"

echo "Waiting for ODF operator to be ready..."
oc wait --for=condition=AtLatestDesiredRevision deployment/odf-operator-controller-manager -n openshift-storage --timeout=300s
check_status "ODF Operator readiness"

# Step 2: Deploy Infrastructure Nodes
echo "Step 2: Deploying ODF Infrastructure Nodes..."
oc kustomize kohler-openshift/components/odf-infrastructure | oc apply -f -
check_status "ODF Infrastructure deployment"

echo "Waiting for infrastructure nodes to be ready..."
sleep 60

# Check node status
echo "Checking infrastructure node status..."
oc get nodes | grep odf-infra || echo "⚠️  Infrastructure nodes not yet visible"

# Step 3: Deploy ODF Storage Cluster
echo "Step 3: Deploying ODF Storage Cluster..."
oc kustomize kohler-openshift/components/odf-configuration | oc apply -f -
check_status "ODF Storage Cluster deployment"

echo "Waiting for storage cluster to initialize..."
sleep 30

# Step 4: Verification
echo "Step 4: Verifying ODF Installation..."

echo "Checking ODF operator status..."
oc get subscription -n openshift-storage | grep odf
oc get csv -n openshift-storage | grep odf

echo "Checking infrastructure nodes..."
oc get nodes -l node-role.kubernetes.io/infra= | grep odf-infra || echo "⚠️  No infra nodes found yet"

echo "Checking storage cluster status..."
oc get storagecluster -n openshift-storage

echo "Checking storage classes..."
oc get storageclass | grep ocs || echo "⚠️  Storage classes not yet created"

# Step 5: Post-deployment instructions
echo
echo "=== Post-Deployment Instructions ==="
echo "1. Wait for infrastructure nodes to become Ready (may take 10-15 minutes)"
echo "2. Wait for ODF storage cluster to reach 'Ready' phase"
echo "3. Verify storage classes are created"
echo "4. Test storage provisioning with a test PVC"
echo
echo "=== Monitoring Commands ==="
echo "# Check node status:"
echo "oc get nodes | grep odf-infra"
echo
echo "# Check storage cluster:"
echo "oc get storagecluster -n openshift-storage"
echo
echo "# Check storage classes:"
echo "oc get storageclass | grep ocs"
echo
echo "# Check ODF pods:"
echo "oc get pods -n openshift-storage"
echo
echo "=== Troubleshooting ==="
echo "If nodes don't become Ready, check:"
echo "- vSphere credentials in openshift-machine-api namespace"
echo "- Network connectivity to storage network (VLAN225)"
echo "- Sufficient vSphere resources"
echo
echo "Script completed at $(date)"
echo "ODF deployment initiated successfully!"
