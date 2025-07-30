#!/bin/bash

# OADP GitOps Deployment Verification Script
# This script verifies that OADP components are properly deployed via GitOps

set -e

echo "🔍 OADP GitOps Deployment Verification"
echo "======================================"
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

# Function to check resource with timeout
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local timeout=${4:-60}
    
    echo "🔍 Checking $resource_type/$resource_name in namespace $namespace..."
    
    if timeout $timeout bash -c "until oc get $resource_type/$resource_name -n $namespace >/dev/null 2>&1; do sleep 5; done"; then
        echo "✅ $resource_type/$resource_name exists"
        return 0
    else
        echo "❌ $resource_type/$resource_name not found or timeout"
        return 1
    fi
}

# Function to get colored status
get_status_color() {
    case $1 in
        "Completed"|"Available"|"Succeeded") echo "✅ $1" ;;
        "InProgress"|"Progressing"|"Installing") echo "🔄 $1" ;;
        "Failed"|"Error"|"PartiallyFailed") echo "❌ $1" ;;
        "New"|"Pending") echo "⏳ $1" ;;
        *) echo "⚪ $1" ;;
    esac
}

echo "📦 Step 1: Verifying OADP Operator Component (Sync Wave 5)"
echo "--------------------------------------------------------"

# Check namespace
if check_resource "namespace" "openshift-adp" "" 30; then
    echo "✅ OADP namespace exists"
else
    echo "❌ OADP namespace not found - operator component may not be deployed"
    exit 1
fi

# Check OperatorGroup
if check_resource "operatorgroup" "redhat-oadp-operator" "openshift-adp" 30; then
    echo "✅ OADP OperatorGroup exists"
else
    echo "❌ OADP OperatorGroup not found"
fi

# Check Subscription
if check_resource "subscription" "redhat-oadp-operator" "openshift-adp" 30; then
    echo "✅ OADP Subscription exists"
    
    # Check subscription status
    SUB_STATE=$(oc get subscription redhat-oadp-operator -n openshift-adp -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
    echo "   Subscription State: $(get_status_color "$SUB_STATE")"
else
    echo "❌ OADP Subscription not found"
fi

# Check CSV (ClusterServiceVersion)
echo "🔍 Checking for OADP ClusterServiceVersion..."
if oc get csv -n openshift-adp -o jsonpath='{.items[?(@.metadata.name=~"oadp-operator.*")].metadata.name}' | grep -q oadp-operator; then
    CSV_NAME=$(oc get csv -n openshift-adp -o jsonpath='{.items[?(@.metadata.name=~"oadp-operator.*")].metadata.name}')
    CSV_PHASE=$(oc get csv -n openshift-adp -o jsonpath='{.items[?(@.metadata.name=~"oadp-operator.*")].status.phase}')
    echo "✅ OADP CSV exists: $CSV_NAME"
    echo "   CSV Phase: $(get_status_color "$CSV_PHASE")"
else
    echo "❌ OADP CSV not found - operator may still be installing"
fi

echo ""
echo "⚙️  Step 2: Verifying OADP Configuration Component (Sync Wave 15)"
echo "---------------------------------------------------------------"

# Check cloud credentials secret
if check_resource "secret" "cloud-credentials" "openshift-adp" 30; then
    echo "✅ Cloud credentials secret exists"
else
    echo "❌ Cloud credentials secret not found - configuration component may not be deployed"
fi

# Check DataProtectionApplication
if check_resource "dataprotectionapplication" "ocp-prd-velero-config" "openshift-adp" 30; then
    echo "✅ DataProtectionApplication exists"
    
    # Check DPA status
    DPA_PHASE=$(oc get dpa ocp-prd-velero-config -n openshift-adp -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "   DPA Phase: $(get_status_color "$DPA_PHASE")"
else
    echo "❌ DataProtectionApplication not found - configuration component may not be deployed"
fi

# Check Velero deployment
echo "🔍 Checking Velero deployment..."
if check_resource "deployment" "velero" "openshift-adp" 60; then
    REPLICAS=$(oc get deployment velero -n openshift-adp -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
    READY_REPLICAS=$(oc get deployment velero -n openshift-adp -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    echo "✅ Velero deployment exists"
    echo "   Replicas: $READY_REPLICAS/$REPLICAS"
    
    if [ "$READY_REPLICAS" = "$REPLICAS" ] && [ "$REPLICAS" != "0" ]; then
        echo "   Status: ✅ Ready"
    else
        echo "   Status: ⏳ Not ready"
    fi
else
    echo "❌ Velero deployment not found"
fi

# Check backup storage locations
echo "🔍 Checking backup storage locations..."
if oc get backupstoragelocations -n openshift-adp >/dev/null 2>&1; then
    BSL_COUNT=$(oc get backupstoragelocations -n openshift-adp --no-headers | wc -l)
    echo "✅ Found $BSL_COUNT backup storage location(s)"
    
    oc get backupstoragelocations -n openshift-adp -o custom-columns=NAME:.metadata.name,PHASE:.status.phase --no-headers | while read name phase; do
        echo "   - $name: $(get_status_color "$phase")"
    done
else
    echo "❌ No backup storage locations found"
fi

echo ""
echo "📅 Step 3: Verifying OADP Scheduled Backups Component (Sync Wave 25)"
echo "-------------------------------------------------------------------"

# Check scheduled backups
if oc get schedule -n openshift-adp >/dev/null 2>&1; then
    SCHEDULE_COUNT=$(oc get schedule -n openshift-adp --no-headers | wc -l)
    if [ $SCHEDULE_COUNT -eq 0 ]; then
        echo "❌ No scheduled backups found - scheduled backups component may not be deployed"
    else
        echo "✅ Found $SCHEDULE_COUNT scheduled backup(s):"
        oc get schedule -n openshift-adp -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule,LAST-BACKUP:.status.lastBackup --no-headers | while read name schedule lastbackup; do
            echo "   - $name: $schedule (Last: $lastbackup)"
        done
    fi
else
    echo "❌ Unable to check scheduled backups"
fi

echo ""
echo "📊 Summary"
echo "=========="

# Overall status check
OPERATOR_OK=false
CONFIG_OK=false
SCHEDULES_OK=false

# Check operator
if oc get csv -n openshift-adp -o jsonpath='{.items[?(@.metadata.name=~"oadp-operator.*")].status.phase}' | grep -q Succeeded; then
    OPERATOR_OK=true
fi

# Check configuration
if oc get dpa ocp-prd-velero-config -n openshift-adp >/dev/null 2>&1 && oc get deployment velero -n openshift-adp >/dev/null 2>&1; then
    CONFIG_OK=true
fi

# Check schedules
if [ "$(oc get schedule -n openshift-adp --no-headers | wc -l)" -gt 0 ]; then
    SCHEDULES_OK=true
fi

echo "Component Status:"
if $OPERATOR_OK; then
    echo "✅ OADP Operator: Deployed and Ready"
else
    echo "❌ OADP Operator: Not Ready"
fi

if $CONFIG_OK; then
    echo "✅ OADP Configuration: Deployed and Ready"
else
    echo "❌ OADP Configuration: Not Ready"
fi

if $SCHEDULES_OK; then
    echo "✅ OADP Scheduled Backups: Deployed"
else
    echo "❌ OADP Scheduled Backups: Not Deployed"
fi

echo ""
if $OPERATOR_OK && $CONFIG_OK && $SCHEDULES_OK; then
    echo "🎉 All OADP components are successfully deployed via GitOps!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Test backup functionality"
    echo "2. Monitor scheduled backup execution"
    echo "3. Verify backup storage connectivity"
else
    echo "⚠️  Some OADP components are not ready. Check ArgoCD applications and sync status."
    echo ""
    echo "🔧 Troubleshooting:"
    echo "1. Check ArgoCD application sync status"
    echo "2. Verify sync wave ordering"
    echo "3. Check for resource conflicts or errors"
fi

echo ""
echo "🔧 Useful Commands:"
echo "==================="
echo "• Monitor backup status:      ./scripts/check-backup-status.sh"
echo "• View ArgoCD applications:   oc get applications -n openshift-gitops"
echo "• Check OADP operator logs:   oc logs -n openshift-adp deployment/oadp-operator"
echo "• Check Velero logs:          oc logs -n openshift-adp deployment/velero"
echo "• List all backups:           oc get backup -n openshift-adp"
