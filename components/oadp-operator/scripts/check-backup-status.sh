#!/bin/bash

# Backup Status Monitoring Script
# This script provides detailed status information about OADP backups

set -e

NAMESPACE="openshift-adp"

echo "🔍 OADP Backup Status Monitor"
echo "============================="
echo ""

# Check if OADP is installed
if ! oc get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "❌ OADP namespace not found. Is OADP installed?"
    exit 1
fi

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

# Check OADP Operator Status
echo "📦 OADP Operator Status:"
if oc get csv -n $NAMESPACE -o custom-columns=NAME:.metadata.name,PHASE:.status.phase --no-headers 2>/dev/null | grep redhat-oadp-operator; then
    OPERATOR_STATUS=$(oc get csv -n $NAMESPACE -o jsonpath='{.items[?(@.metadata.name=~"redhat-oadp-operator.*")].status.phase}')
    echo "   $(get_status_color "$OPERATOR_STATUS")"
else
    echo "   ❌ OADP Operator not found"
fi
echo ""

# Check Data Protection Application Status
echo "⚙️  Data Protection Application Status:"
if oc get dpa -n $NAMESPACE >/dev/null 2>&1; then
    DPA_COUNT=$(oc get dpa -n $NAMESPACE --no-headers | wc -l)
    echo "   Found $DPA_COUNT DPA(s):"
    oc get dpa -n $NAMESPACE -o custom-columns=NAME:.metadata.name,PHASE:.status.phase --no-headers | while read name phase; do
        echo "   - $name: $(get_status_color "$phase")"
    done
else
    echo "   ❌ No Data Protection Applications found"
fi
echo ""

# Check Velero Deployment Status
echo "🚀 Velero Deployment Status:"
if oc get deployment velero -n $NAMESPACE >/dev/null 2>&1; then
    REPLICAS=$(oc get deployment velero -n $NAMESPACE -o jsonpath='{.status.replicas}')
    READY_REPLICAS=$(oc get deployment velero -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    echo "   Replicas: $READY_REPLICAS/$REPLICAS"
    
    DEPLOYMENT_STATUS=$(oc get deployment velero -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
    if [ "$DEPLOYMENT_STATUS" = "True" ]; then
        echo "   Status: ✅ Available"
    else
        echo "   Status: ❌ Not Available"
    fi
else
    echo "   ❌ Velero deployment not found"
fi
echo ""

# Check Backup Storage Locations
echo "🗄️  Backup Storage Locations:"
if oc get backupstoragelocations -n $NAMESPACE >/dev/null 2>&1; then
    oc get backupstoragelocations -n $NAMESPACE -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,AVAILABLE:.status.lastSyncedTime --no-headers | while read name phase lastsynced; do
        echo "   - $name: $(get_status_color "$phase") (Last sync: $lastsynced)"
    done
else
    echo "   ❌ No backup storage locations found"
fi
echo ""

# Check Volume Snapshot Locations
echo "📸 Volume Snapshot Locations:"
if oc get volumesnapshotlocations -n $NAMESPACE >/dev/null 2>&1; then
    oc get volumesnapshotlocations -n $NAMESPACE -o custom-columns=NAME:.metadata.name,AVAILABLE:.status.availableTime --no-headers | while read name available; do
        echo "   - $name: Available since $available"
    done
else
    echo "   ❌ No volume snapshot locations found"
fi
echo ""

# Check Recent Backups
echo "💾 Recent Backups (Last 10):"
if oc get backup -n $NAMESPACE >/dev/null 2>&1; then
    BACKUP_COUNT=$(oc get backup -n $NAMESPACE --no-headers | wc -l)
    if [ $BACKUP_COUNT -eq 0 ]; then
        echo "   No backups found"
    else
        echo "   Found $BACKUP_COUNT total backup(s):"
        oc get backup -n $NAMESPACE --sort-by='.metadata.creationTimestamp' -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,STARTED:.status.startTimestamp,COMPLETED:.status.completionTimestamp --no-headers | tail -10 | while read name status started completed; do
            echo "   - $name: $(get_status_color "$status")"
            echo "     Started: $started"
            if [ "$completed" != "<none>" ]; then
                echo "     Completed: $completed"
            fi
        done
    fi
else
    echo "   ❌ Unable to list backups"
fi
echo ""

# Check Recent Restores
echo "🔄 Recent Restores (Last 5):"
if oc get restore -n $NAMESPACE >/dev/null 2>&1; then
    RESTORE_COUNT=$(oc get restore -n $NAMESPACE --no-headers | wc -l)
    if [ $RESTORE_COUNT -eq 0 ]; then
        echo "   No restores found"
    else
        echo "   Found $RESTORE_COUNT total restore(s):"
        oc get restore -n $NAMESPACE --sort-by='.metadata.creationTimestamp' -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,STARTED:.status.startTimestamp,COMPLETED:.status.completionTimestamp --no-headers | tail -5 | while read name status started completed; do
            echo "   - $name: $(get_status_color "$status")"
            echo "     Started: $started"
            if [ "$completed" != "<none>" ]; then
                echo "     Completed: $completed"
            fi
        done
    fi
else
    echo "   ❌ Unable to list restores"
fi
echo ""

# Check Scheduled Backups
echo "⏰ Scheduled Backups:"
if oc get schedule -n $NAMESPACE >/dev/null 2>&1; then
    SCHEDULE_COUNT=$(oc get schedule -n $NAMESPACE --no-headers | wc -l)
    if [ $SCHEDULE_COUNT -eq 0 ]; then
        echo "   No scheduled backups found"
    else
        echo "   Found $SCHEDULE_COUNT scheduled backup(s):"
        oc get schedule -n $NAMESPACE -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule,LAST-BACKUP:.status.lastBackup --no-headers | while read name schedule lastbackup; do
            echo "   - $name: $schedule (Last: $lastbackup)"
        done
    fi
else
    echo "   ❌ Unable to list scheduled backups"
fi
echo ""

# Check Pod Status
echo "🔧 OADP Pod Status:"
oc get pods -n $NAMESPACE -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount

echo ""
echo "📊 Summary Commands:"
echo "==================="
echo "• View all backups:           oc get backup -n $NAMESPACE"
echo "• View backup details:        oc describe backup <backup-name> -n $NAMESPACE"
echo "• View Velero logs:           oc logs -n $NAMESPACE deployment/velero"
echo "• View Restic logs:           oc logs -n $NAMESPACE daemonset/restic"
echo "• Create manual backup:       oc apply -f examples/backup-example.yaml"
echo "• Monitor backup progress:    oc get backup <backup-name> -n $NAMESPACE -w"
