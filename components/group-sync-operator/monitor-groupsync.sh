#!/bin/bash
# Monitor Group Sync Operator status and group synchronization
# This script provides a comprehensive overview of the Group Sync Operator deployment

set -e

echo "🔍 Group Sync Operator Monitoring Dashboard"
echo "=========================================="
echo ""

# Check if we're connected to the cluster
if ! oc whoami >/dev/null 2>&1; then
    echo "❌ Not connected to OpenShift cluster. Please run 'oc login' first."
    exit 1
fi

echo "✅ Connected to OpenShift cluster: $(oc whoami --show-server)"
echo ""

# Check namespace
echo "📁 Namespace Status:"
if oc get namespace group-sync-operator >/dev/null 2>&1; then
    echo "✅ group-sync-operator namespace exists"
    NAMESPACE_STATUS="exists"
else
    echo "❌ group-sync-operator namespace not found"
    NAMESPACE_STATUS="missing"
    echo "   The component may not be deployed yet."
    echo ""
    exit 1
fi

echo ""

# Check operator pods
echo "🐳 Operator Pods:"
if [ "$NAMESPACE_STATUS" = "exists" ]; then
    PODS=$(oc get pods -n group-sync-operator --no-headers 2>/dev/null || true)
    if [ -n "$PODS" ]; then
        echo "$PODS" | while read -r line; do
            if echo "$line" | grep -q "Running"; then
                echo "✅ $line"
            elif echo "$line" | grep -q "Pending\|CrashLoopBackOff\|Error"; then
                echo "❌ $line"
            else
                echo "⚠️  $line"
            fi
        done
    else
        echo "❌ No pods found in group-sync-operator namespace"
    fi
fi

echo ""

# Check operator resources
echo "🔧 Operator Resources:"
if [ "$NAMESPACE_STATUS" = "exists" ]; then
    echo "📋 OperatorGroup:"
    if oc get operatorgroup -n group-sync-operator 2>/dev/null | grep -q "group-sync-operator"; then
        echo "✅ OperatorGroup exists"
    else
        echo "❌ OperatorGroup not found"
    fi
    
    echo "📋 Subscription:"
    if oc get subscription -n group-sync-operator 2>/dev/null | grep -q "group-sync-operator"; then
        echo "✅ Subscription exists"
        SUB=$(oc get subscription group-sync-operator -n group-sync-operator -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        echo "   Status: $SUB"
    else
        echo "❌ Subscription not found"
    fi
fi

echo ""

# Check GroupSync configuration
echo "🔄 GroupSync Configuration:"
if [ "$NAMESPACE_STATUS" = "exists" ]; then
    if oc get groupsync -n group-sync-operator 2>/dev/null | grep -q "azure-ad-groupsync"; then
        echo "✅ GroupSync configuration exists"
        
        # Get GroupSync details
        GS_STATUS=$(oc get groupsync azure-ad-groupsync -n group-sync-operator -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
        GS_MESSAGE=$(oc get groupsync azure-ad-groupsync -n group-sync-operator -o jsonpath='{.status.conditions[0].message}' 2>/dev/null || echo "No message")
        
        echo "   Status: $GS_STATUS"
        echo "   Message: $GS_MESSAGE"
        
        # Check last sync time
        LAST_SYNC=$(oc get groupsync azure-ad-groupsync -n group-sync-operator -o jsonpath='{.status.lastSyncTime}' 2>/dev/null || echo "Never")
        echo "   Last Sync: $LAST_SYNC"
    else
        echo "❌ GroupSync configuration not found"
    fi
fi

echo ""

# Check Azure AD credentials
echo "🔐 Azure AD Credentials:"
if [ "$NAMESPACE_STATUS" = "exists" ]; then
    if oc get secret azure-ad-credentials -n group-sync-operator >/dev/null 2>&1; then
        echo "✅ Azure AD credentials secret exists"
        
        # Check if secret has required keys
        if oc get secret azure-ad-credentials -n group-sync-operator -o jsonpath='{.data.clientSecret}' >/dev/null 2>&1; then
            echo "✅ Client secret configured"
        else
            echo "❌ Client secret missing"
        fi
        
        if oc get secret azure-ad-credentials -n group-sync-operator -o jsonpath='{.data.tenantId}' >/dev/null 2>&1; then
            echo "✅ Tenant ID configured"
        else
            echo "❌ Tenant ID missing"
        fi
        
        if oc get secret azure-ad-credentials -n group-sync-operator -o jsonpath='{.data.clientId}' >/dev/null 2>&1; then
            echo "✅ Client ID configured"
        else
            echo "❌ Client ID missing"
        fi
    else
        echo "❌ Azure AD credentials secret not found"
        echo "   Run the setup-azure-credentials.sh script to configure credentials"
    fi
fi

echo ""

# Check synchronized groups
echo "👥 Synchronized Groups:"
SYNCED_GROUPS=$(oc get groups 2>/dev/null | grep "azure-openshift" || true)
if [ -n "$SYNCED_GROUPS" ]; then
    echo "✅ Found synchronized groups:"
    echo "$SYNCED_GROUPS" | while read -r line; do
        GROUP_NAME=$(echo "$line" | awk '{print $1}')
        GROUP_USERS=$(oc get group "$GROUP_NAME" -o jsonpath='{.users}' 2>/dev/null || echo "0")
        USER_COUNT=$(echo "$GROUP_USERS" | tr ',' '\n' | wc -l)
        echo "   📋 $GROUP_NAME ($USER_COUNT users)"
    done
else
    echo "⚠️  No synchronized groups found yet"
    echo "   This is normal if the operator hasn't completed its first sync"
fi

echo ""

# Check recent events
echo "📊 Recent Events:"
if [ "$NAMESPACE_STATUS" = "exists" ]; then
    RECENT_EVENTS=$(oc get events -n group-sync-operator --sort-by='.lastTimestamp' --no-headers 2>/dev/null | tail -5 || true)
    if [ -n "$RECENT_EVENTS" ]; then
        echo "$RECENT_EVENTS" | while read -r line; do
            if echo "$line" | grep -q "Error\|Failed"; then
                echo "❌ $line"
            elif echo "$line" | grep -q "Warning"; then
                echo "⚠️  $line"
            else
                echo "✅ $line"
            fi
        done
    else
        echo "ℹ️  No recent events found"
    fi
fi

echo ""

# Summary and recommendations
echo "📋 Summary & Recommendations:"
echo "=============================="

if [ "$NAMESPACE_STATUS" = "missing" ]; then
    echo "❌ Component not deployed"
    echo "   Enable group-sync-operator in your cluster values.yaml"
elif [ "$NAMESPACE_STATUS" = "exists" ]; then
    # Check if everything is working
    PODS_RUNNING=$(oc get pods -n group-sync-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    CREDS_EXIST=$(oc get secret azure-ad-credentials -n group-sync-operator >/dev/null 2>&1 && echo "yes" || echo "no")
    GROUPSYNC_EXISTS=$(oc get groupsync azure-ad-groupsync -n group-sync-operator >/dev/null 2>&1 && echo "yes" || echo "no")
    
    if [ "$PODS_RUNNING" -gt 0 ] && [ "$CREDS_EXIST" = "yes" ] && [ "$GROUPSYNC_EXISTS" = "yes" ]; then
        echo "✅ Component is properly configured and running"
        echo "   Monitor group synchronization with: oc get groups"
        echo "   Check operator logs with: oc logs -n group-sync-operator -l app=group-sync-operator"
    else
        echo "⚠️  Component needs attention:"
        if [ "$PODS_RUNNING" -eq 0 ]; then
            echo "   - Operator pods are not running"
        fi
        if [ "$CREDS_EXIST" = "no" ]; then
            echo "   - Azure AD credentials not configured"
            echo "     Run: ./setup-azure-credentials.sh"
        fi
        if [ "$GROUPSYNC_EXISTS" = "no" ]; then
            echo "   - GroupSync configuration missing"
        fi
    fi
fi

echo ""
echo "🔍 For detailed troubleshooting, check:"
echo "   - Operator logs: oc logs -n group-sync-operator -l app=group-sync-operator"
echo "   - GroupSync status: oc describe groupsync azure-ad-groupsync -n group-sync-operator"
echo "   - Cluster events: oc get events -n group-sync-operator"
echo ""
echo "✅ Monitoring complete!"
