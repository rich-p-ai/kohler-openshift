#!/bin/bash

# OADP App Backup Verification Script
# Verifies that daily app namespace backups are configured and working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="openshift-adp"

echo -e "${BLUE}🔍 OADP App Namespace Backup Verification${NC}"
echo "=============================================="
echo ""

# Function to get colored status
get_status_color() {
    case $1 in
        "Completed"|"Available"|"Succeeded") echo -e "${GREEN}✅ $1${NC}" ;;
        "InProgress"|"Progressing"|"Installing") echo -e "${YELLOW}🔄 $1${NC}" ;;
        "Failed"|"Error"|"PartiallyFailed") echo -e "${RED}❌ $1${NC}" ;;
        "New"|"Pending") echo -e "${YELLOW}⏳ $1${NC}" ;;
        *) echo -e "${BLUE}⚪ $1${NC}" ;;
    esac
}

echo -e "${BLUE}📋 Step 1: Checking OADP Installation${NC}"
echo "----------------------------------------"

# Check if connected to cluster
if ! oc whoami >/dev/null 2>&1; then
    echo -e "${RED}❌ Not connected to OpenShift cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Connected to: $(oc whoami --show-server)${NC}"
echo -e "${GREEN}✅ User: $(oc whoami)${NC}"

# Check OADP namespace
if oc get namespace $NAMESPACE >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OADP namespace exists${NC}"
else
    echo -e "${RED}❌ OADP namespace not found${NC}"
    exit 1
fi

# Check OADP operator
if oc get csv -n $NAMESPACE | grep -q redhat-oadp-operator; then
    OPERATOR_STATUS=$(oc get csv -n $NAMESPACE -o jsonpath='{.items[?(@.metadata.name=~"redhat-oadp-operator.*")].status.phase}')
    echo -e "✅ OADP Operator: $(get_status_color "$OPERATOR_STATUS")"
else
    echo -e "${RED}❌ OADP Operator not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📋 Step 2: Checking Backup Storage Configuration${NC}"
echo "------------------------------------------------"

# Check backup storage locations
if oc get backupstoragelocations -n $NAMESPACE >/dev/null 2>&1; then
    BSL_COUNT=$(oc get backupstoragelocations -n $NAMESPACE --no-headers | wc -l)
    echo -e "${GREEN}✅ Found $BSL_COUNT backup storage location(s)${NC}"
    
    oc get backupstoragelocations -n $NAMESPACE -o custom-columns=NAME:.metadata.name,PHASE:.status.phase --no-headers | while read name phase; do
        echo -e "   - $name: $(get_status_color "$phase")"
    done
else
    echo -e "${RED}❌ No backup storage locations found${NC}"
    exit 1
fi

# Check volume snapshot locations
if oc get volumesnapshotlocations -n $NAMESPACE >/dev/null 2>&1; then
    VSL_COUNT=$(oc get volumesnapshotlocations -n $NAMESPACE --no-headers | wc -l)
    echo -e "${GREEN}✅ Found $VSL_COUNT volume snapshot location(s)${NC}"
else
    echo -e "${YELLOW}⚠️  No volume snapshot locations found${NC}"
fi

echo ""
echo -e "${BLUE}📋 Step 3: Checking Scheduled Backups${NC}"
echo "--------------------------------------"

# Check all scheduled backups
if oc get schedule -n $NAMESPACE >/dev/null 2>&1; then
    SCHEDULE_COUNT=$(oc get schedule -n $NAMESPACE --no-headers | wc -l)
    echo -e "${GREEN}✅ Found $SCHEDULE_COUNT scheduled backup(s)${NC}"
    
    echo ""
    echo "📅 Scheduled Backups:"
    oc get schedule -n $NAMESPACE -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule,LAST-BACKUP:.status.lastBackup
    
    # Check specifically for app namespace backup
    if oc get schedule daily-app-namespace-backup -n $NAMESPACE >/dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}✅ App namespace backup schedule found${NC}"
        
        # Get details of the app backup schedule
        echo ""
        echo "📋 App Backup Schedule Details:"
        echo "  Name: daily-app-namespace-backup"
        echo "  Schedule: $(oc get schedule daily-app-namespace-backup -n $NAMESPACE -o jsonpath='{.spec.schedule}')"
        echo "  Last Backup: $(oc get schedule daily-app-namespace-backup -n $NAMESPACE -o jsonpath='{.status.lastBackup}')"
        
        # Show included namespaces
        echo ""
        echo "📂 Included Namespaces:"
        oc get schedule daily-app-namespace-backup -n $NAMESPACE -o jsonpath='{.spec.template.spec.includedNamespaces[*]}' | tr ' ' '\n' | sed 's/^/  - /'
        
    else
        echo -e "${YELLOW}⚠️  App namespace backup schedule not found${NC}"
        echo "   Run: oc apply -f app-namespace-daily-backup.yaml"
    fi
else
    echo -e "${RED}❌ No scheduled backups found${NC}"
fi

echo ""
echo -e "${BLUE}📋 Step 4: Checking Recent Backups${NC}"
echo "-----------------------------------"

# Check recent backups
if oc get backup -n $NAMESPACE >/dev/null 2>&1; then
    BACKUP_COUNT=$(oc get backup -n $NAMESPACE --no-headers | wc -l)
    echo -e "${GREEN}✅ Found $BACKUP_COUNT backup(s)${NC}"
    
    if [ $BACKUP_COUNT -gt 0 ]; then
        echo ""
        echo "📊 Recent Backups (last 10):"
        oc get backup -n $NAMESPACE --sort-by=.metadata.creationTimestamp -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CREATED:.metadata.creationTimestamp | tail -11
        
        # Check for failed backups
        FAILED_COUNT=$(oc get backup -n $NAMESPACE -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' | wc -w)
        if [ $FAILED_COUNT -gt 0 ]; then
            echo ""
            echo -e "${RED}❌ Found $FAILED_COUNT failed backup(s)${NC}"
            echo "Failed backups:"
            oc get backup -n $NAMESPACE -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' | tr ' ' '\n' | sed 's/^/  - /'
        else
            echo -e "${GREEN}✅ No failed backups found${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  No backups found yet${NC}"
fi

echo ""
echo -e "${BLUE}📋 Step 5: Checking Velero Status${NC}"
echo "----------------------------------"

# Check Velero deployment
if oc get deployment velero -n $NAMESPACE >/dev/null 2>&1; then
    REPLICAS=$(oc get deployment velero -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    READY_REPLICAS=$(oc get deployment velero -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    
    if [ "$READY_REPLICAS" = "$REPLICAS" ] && [ "$REPLICAS" != "0" ]; then
        echo -e "${GREEN}✅ Velero deployment ready ($READY_REPLICAS/$REPLICAS)${NC}"
    else
        echo -e "${YELLOW}⚠️  Velero deployment not ready ($READY_REPLICAS/$REPLICAS)${NC}"
    fi
    
    # Check Velero pod status
    echo ""
    echo "🔧 Velero Pod Status:"
    oc get pods -n $NAMESPACE -l app.kubernetes.io/name=velero -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount
else
    echo -e "${RED}❌ Velero deployment not found${NC}"
fi

echo ""
echo -e "${BLUE}📋 Summary${NC}"
echo "----------"

# Overall health check
echo "📊 Component Status:"

# Check operator
if oc get csv -n $NAMESPACE -o jsonpath='{.items[?(@.metadata.name=~"redhat-oadp-operator.*")].status.phase}' | grep -q Succeeded; then
    echo -e "  ${GREEN}✅ OADP Operator: Ready${NC}"
else
    echo -e "  ${RED}❌ OADP Operator: Not Ready${NC}"
fi

# Check storage
if oc get backupstoragelocations -n $NAMESPACE -o jsonpath='{.items[*].status.phase}' | grep -q Available; then
    echo -e "  ${GREEN}✅ Backup Storage: Available${NC}"
else
    echo -e "  ${RED}❌ Backup Storage: Not Available${NC}"
fi

# Check schedules
if oc get schedule daily-app-namespace-backup -n $NAMESPACE >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ App Backup Schedule: Configured${NC}"
else
    echo -e "  ${YELLOW}⚠️  App Backup Schedule: Not Configured${NC}"
fi

# Check Velero
if oc get deployment velero -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q "1"; then
    echo -e "  ${GREEN}✅ Velero: Running${NC}"
else
    echo -e "  ${RED}❌ Velero: Not Running${NC}"
fi

echo ""
echo -e "${BLUE}🔗 Useful Commands${NC}"
echo "-------------------"
echo "• View backup status:        oc get backup -n $NAMESPACE"
echo "• View backup details:       oc describe backup <backup-name> -n $NAMESPACE"
echo "• View Velero logs:          oc logs -n $NAMESPACE deployment/velero"
echo "• Monitor backup progress:   oc get backup -n $NAMESPACE -w"
echo "• Create manual backup:      oc apply -f app-namespace-daily-backup.yaml"
echo "• Check storage location:    oc get backupstoragelocations -n $NAMESPACE"

echo ""
echo -e "${GREEN}🎉 Verification Complete!${NC}"
