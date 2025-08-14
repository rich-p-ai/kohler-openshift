#!/bin/bash

# ODF Configuration Verification Script
# This script compares the GitOps configuration with the actual ocp-prd cluster settings

set -e

echo "🔍 ODF Configuration Verification for OCP-PRD"
echo "=============================================="
echo ""

# Check if logged into the correct cluster
CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null || echo "not-logged-in")
EXPECTED_SERVER="https://api.ocp-prd.kohlerco.com:6443"

if [[ "$CURRENT_SERVER" != "$EXPECTED_SERVER" ]]; then
    echo "❌ Error: Not logged into the correct cluster"
    echo "Current: $CURRENT_SERVER"
    echo "Expected: $EXPECTED_SERVER"
    echo ""
    echo "Please login to OCP-PRD cluster first:"
    echo "oc login $EXPECTED_SERVER"
    exit 1
fi

echo "✅ Connected to OCP-PRD cluster"
echo "Server: $CURRENT_SERVER"
echo ""

echo "📊 Comparing GitOps Configuration vs Cluster Configuration"
echo "=========================================================="

# Function to get colored status
get_status_color() {
    case $1 in
        "MATCH") echo "✅ $1" ;;
        "MISMATCH") echo "❌ $1" ;;
        "WARNING") echo "⚠️ $1" ;;
        *) echo "⚪ $1" ;;
    esac
}

echo ""
echo "1️⃣ StorageSystem Configuration"
echo "------------------------------"

# Check StorageSystem name and namespace
CLUSTER_SS_NAME=$(oc get storagesystem -n openshift-storage -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
CLUSTER_SS_NAMESPACE=$(oc get storagesystem -n openshift-storage -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "")

GITOPS_SS_NAME="ocs-storagecluster-storagesystem"
GITOPS_SS_NAMESPACE="openshift-storage"

if [[ "$CLUSTER_SS_NAME" == "$GITOPS_SS_NAME" ]]; then
    echo "StorageSystem Name: $(get_status_color "MATCH") ($GITOPS_SS_NAME)"
else
    echo "StorageSystem Name: $(get_status_color "MISMATCH") - GitOps: $GITOPS_SS_NAME, Cluster: $CLUSTER_SS_NAME"
fi

if [[ "$CLUSTER_SS_NAMESPACE" == "$GITOPS_SS_NAMESPACE" ]]; then
    echo "StorageSystem Namespace: $(get_status_color "MATCH") ($GITOPS_SS_NAMESPACE)"
else
    echo "StorageSystem Namespace: $(get_status_color "MISMATCH") - GitOps: $GITOPS_SS_NAMESPACE, Cluster: $CLUSTER_SS_NAMESPACE"
fi

echo ""
echo "2️⃣ StorageCluster Configuration"
echo "-------------------------------"

# Check StorageCluster name
CLUSTER_SC_NAME=$(oc get storagecluster -n openshift-storage -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
GITOPS_SC_NAME="ocs-storagecluster"

if [[ "$CLUSTER_SC_NAME" == "$GITOPS_SC_NAME" ]]; then
    echo "StorageCluster Name: $(get_status_color "MATCH") ($GITOPS_SC_NAME)"
else
    echo "StorageCluster Name: $(get_status_color "MISMATCH") - GitOps: $GITOPS_SC_NAME, Cluster: $CLUSTER_SC_NAME"
fi

# Check storage class
CLUSTER_STORAGE_CLASS=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.spec.storageDeviceSets[0].dataPVCTemplate.spec.storageClassName}' 2>/dev/null || echo "")
GITOPS_STORAGE_CLASS="thin-csi"

if [[ "$CLUSTER_STORAGE_CLASS" == "$GITOPS_STORAGE_CLASS" ]]; then
    echo "Storage Class: $(get_status_color "MATCH") ($GITOPS_STORAGE_CLASS)"
else
    echo "Storage Class: $(get_status_color "MISMATCH") - GitOps: $GITOPS_STORAGE_CLASS, Cluster: $CLUSTER_STORAGE_CLASS"
fi

# Check storage size
CLUSTER_STORAGE_SIZE=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.spec.storageDeviceSets[0].dataPVCTemplate.spec.resources.requests.storage}' 2>/dev/null || echo "")
GITOPS_STORAGE_SIZE="2Ti"

if [[ "$CLUSTER_STORAGE_SIZE" == "$GITOPS_STORAGE_SIZE" ]]; then
    echo "Storage Size: $(get_status_color "MATCH") ($GITOPS_STORAGE_SIZE)"
else
    echo "Storage Size: $(get_status_color "MISMATCH") - GitOps: $GITOPS_STORAGE_SIZE, Cluster: $CLUSTER_STORAGE_SIZE"
fi

# Check replica count
CLUSTER_REPLICA=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.spec.storageDeviceSets[0].replica}' 2>/dev/null || echo "")
GITOPS_REPLICA="3"

if [[ "$CLUSTER_REPLICA" == "$GITOPS_REPLICA" ]]; then
    echo "Replica Count: $(get_status_color "MATCH") ($GITOPS_REPLICA)"
else
    echo "Replica Count: $(get_status_color "MISMATCH") - GitOps: $GITOPS_REPLICA, Cluster: $CLUSTER_REPLICA"
fi

# Check resource profile
CLUSTER_RESOURCE_PROFILE=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.spec.resourceProfile}' 2>/dev/null || echo "")
GITOPS_RESOURCE_PROFILE="lean"

if [[ "$CLUSTER_RESOURCE_PROFILE" == "$GITOPS_RESOURCE_PROFILE" ]]; then
    echo "Resource Profile: $(get_status_color "MATCH") ($GITOPS_RESOURCE_PROFILE)"
else
    echo "Resource Profile: $(get_status_color "MISMATCH") - GitOps: $GITOPS_RESOURCE_PROFILE, Cluster: $CLUSTER_RESOURCE_PROFILE"
fi

echo ""
echo "3️⃣ ODF Operator Configuration"
echo "-----------------------------"

# Check operator subscription
CLUSTER_OPERATOR_CHANNEL=$(oc get subscription odf-operator -n openshift-storage -o jsonpath='{.spec.channel}' 2>/dev/null || echo "")
GITOPS_OPERATOR_CHANNEL="stable-4.18"

if [[ "$CLUSTER_OPERATOR_CHANNEL" == "$GITOPS_OPERATOR_CHANNEL" ]]; then
    echo "Operator Channel: $(get_status_color "MATCH") ($GITOPS_OPERATOR_CHANNEL)"
else
    echo "Operator Channel: $(get_status_color "MISMATCH") - GitOps: $GITOPS_OPERATOR_CHANNEL, Cluster: $CLUSTER_OPERATOR_CHANNEL"
fi

# Check operator source
CLUSTER_OPERATOR_SOURCE=$(oc get subscription odf-operator -n openshift-storage -o jsonpath='{.spec.source}' 2>/dev/null || echo "")
GITOPS_OPERATOR_SOURCE="redhat-operators"

if [[ "$CLUSTER_OPERATOR_SOURCE" == "$GITOPS_OPERATOR_SOURCE" ]]; then
    echo "Operator Source: $(get_status_color "MATCH") ($GITOPS_OPERATOR_SOURCE)"
else
    echo "Operator Source: $(get_status_color "MISMATCH") - GitOps: $GITOPS_OPERATOR_SOURCE, Cluster: $CLUSTER_OPERATOR_SOURCE"
fi

echo ""
echo "4️⃣ Node Configuration"
echo "---------------------"

# Check if dedicated ODF nodes exist
ODF_NODE_COUNT=$(oc get nodes -l cluster.ocs.openshift.io/openshift-storage --no-headers | wc -l)
if [ "$ODF_NODE_COUNT" -gt 0 ]; then
    echo "ODF Dedicated Nodes: $(get_status_color "MATCH") ($ODF_NODE_COUNT nodes found)"
    
    # Show node details
    echo "ODF Node Details:"
    oc get nodes -l cluster.ocs.openshift.io/openshift-storage -o custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.'node-role\.kubernetes\.io/infra',RACK:.metadata.labels.'topology\.rook\.io/rack' --no-headers | while read name role rack; do
        echo "  - $name (Role: $role, Rack: $rack)"
    done
else
    echo "ODF Dedicated Nodes: $(get_status_color "WARNING") (No dedicated ODF nodes found)"
fi

echo ""
echo "5️⃣ Encryption Configuration"
echo "----------------------------"

# Check key rotation schedule
CLUSTER_KEY_ROTATION=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.spec.encryption.keyRotation.schedule}' 2>/dev/null || echo "")
GITOPS_KEY_ROTATION="@weekly"

if [[ "$CLUSTER_KEY_ROTATION" == "$GITOPS_KEY_ROTATION" ]]; then
    echo "Key Rotation Schedule: $(get_status_color "MATCH") ($GITOPS_KEY_ROTATION)"
else
    echo "Key Rotation Schedule: $(get_status_color "MISMATCH") - GitOps: $GITOPS_KEY_ROTATION, Cluster: $CLUSTER_KEY_ROTATION"
fi

echo ""
echo "📋 Overall Assessment"
echo "======================"

# Count matches vs mismatches (this is a simplified check)
TOTAL_CHECKS=8
MATCHES=0

# Re-run key checks for counting
[[ "$CLUSTER_SS_NAME" == "$GITOPS_SS_NAME" ]] && ((MATCHES++))
[[ "$CLUSTER_SC_NAME" == "$GITOPS_SC_NAME" ]] && ((MATCHES++))
[[ "$CLUSTER_STORAGE_CLASS" == "$GITOPS_STORAGE_CLASS" ]] && ((MATCHES++))
[[ "$CLUSTER_STORAGE_SIZE" == "$GITOPS_STORAGE_SIZE" ]] && ((MATCHES++))
[[ "$CLUSTER_REPLICA" == "$GITOPS_REPLICA" ]] && ((MATCHES++))
[[ "$CLUSTER_RESOURCE_PROFILE" == "$GITOPS_RESOURCE_PROFILE" ]] && ((MATCHES++))
[[ "$CLUSTER_OPERATOR_CHANNEL" == "$GITOPS_OPERATOR_CHANNEL" ]] && ((MATCHES++))
[[ "$CLUSTER_KEY_ROTATION" == "$GITOPS_KEY_ROTATION" ]] && ((MATCHES++))

MATCH_PERCENTAGE=$((MATCHES * 100 / TOTAL_CHECKS))

echo "Configuration Match: $MATCHES/$TOTAL_CHECKS checks passed ($MATCH_PERCENTAGE%)"

if [ $MATCHES -eq $TOTAL_CHECKS ]; then
    echo "🎉 All configurations match! GitOps repository is aligned with ocp-prd cluster."
elif [ $MATCHES -ge $((TOTAL_CHECKS * 3 / 4)) ]; then
    echo "✅ Most configurations match. Minor discrepancies may be acceptable."
else
    echo "⚠️ Several configuration mismatches detected. Review and update GitOps repository."
fi

echo ""
echo "🔧 Current Cluster Status"
echo "========================="

# Show current cluster health
echo "StorageCluster Phase: $(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.status.phase}' 2>/dev/null || echo 'Unknown')"
echo "StorageSystem Status: $(oc get storagesystem -n openshift-storage -o jsonpath='{.items[0].status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo 'Unknown')"

# Show storage classes
echo ""
echo "Available ODF Storage Classes:"
oc get storageclass | grep -E "(ocs|ceph|noobaa)" | while read name provisioner reclaim allow default age; do
    echo "  - $name"
done

echo ""
echo "For detailed cluster information, run:"
echo "  oc get all -n openshift-storage"
echo "  oc get storagecluster ocs-storagecluster -n openshift-storage -o yaml"
