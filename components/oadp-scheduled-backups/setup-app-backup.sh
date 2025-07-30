#!/bin/bash

# OADP App Namespace Backup Setup Script
# This script helps you configure and deploy daily backups for your app namespaces

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="openshift-adp"
SCHEDULE_FILE="app-namespace-daily-backup.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}🔧 OADP App Namespace Backup Setup${NC}"
echo "================================================="
echo ""

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_section() {
    echo -e "\n${PURPLE}📋 $1${NC}"
    echo "----------------------------------------"
}

# Function to check prerequisites
check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    # Check if we're connected to a cluster
    if ! oc whoami >/dev/null 2>&1; then
        print_error "Not logged into OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    print_info "Connected to cluster: $(oc whoami --show-server)"
    print_info "Current user: $(oc whoami)"
    
    # Check if OADP namespace exists
    if ! oc get namespace $NAMESPACE >/dev/null 2>&1; then
        print_error "OADP namespace '$NAMESPACE' not found. Is OADP installed?"
        exit 1
    fi
    
    print_success "OADP namespace found"
    
    # Check if OADP operator is running
    if ! oc get csv -n $NAMESPACE | grep -q redhat-oadp-operator; then
        print_error "OADP operator not found. Please install OADP first."
        exit 1
    fi
    
    print_success "OADP operator is installed"
    
    # Check if backup storage location exists
    if ! oc get backupstoragelocations -n $NAMESPACE >/dev/null 2>&1; then
        print_error "No backup storage locations found. Please configure OADP storage first."
        exit 1
    fi
    
    print_success "Backup storage location configured"
}

# Function to show current namespaces
show_namespaces() {
    print_section "AVAILABLE NAMESPACES"
    
    print_info "Here are some application namespaces you might want to backup:"
    echo ""
    
    # Show common app namespaces
    for ns in balance-fit-prd data-analytics humanresourceapps kitchenandbathapps financeapps legalapps crmapplications coldfusion; do
        if oc get namespace "$ns" >/dev/null 2>&1; then
            print_success "Found: $ns"
        fi
    done
    
    echo ""
    print_info "All namespaces (excluding system):"
    oc get namespaces --no-headers | grep -v -E '^(kube-|openshift-|default|istio-|ingress-)' | awk '{print "  - " $1}'
}

# Function to customize backup configuration
customize_backup() {
    print_section "CUSTOMIZE BACKUP CONFIGURATION"
    
    print_info "Current backup schedule configuration:"
    echo "  • Schedule: Daily at 3:00 AM"
    echo "  • Retention: 30 days"
    echo "  • Storage: ocp-host S3 storage"
    echo ""
    
    print_warning "Important: Edit the file '$SCHEDULE_FILE' to customize:"
    echo "  1. Add your app namespace names to 'includedNamespaces'"
    echo "  2. Adjust the schedule time if needed (currently 3:00 AM)"
    echo "  3. Modify retention period if needed (currently 30 days)"
    echo "  4. Add backup hooks for databases if needed"
    echo ""
    
    read -p "Do you want to edit the backup configuration now? (y/N): " edit_config
    if [[ "$edit_config" =~ ^[Yy]$ ]]; then
        if command -v code >/dev/null 2>&1; then
            code "$SCRIPT_DIR/$SCHEDULE_FILE"
        elif command -v nano >/dev/null 2>&1; then
            nano "$SCRIPT_DIR/$SCHEDULE_FILE"
        elif command -v vi >/dev/null 2>&1; then
            vi "$SCRIPT_DIR/$SCHEDULE_FILE"
        else
            print_warning "No editor found. Please manually edit: $SCRIPT_DIR/$SCHEDULE_FILE"
        fi
        
        print_info "Press Enter after you've finished editing the configuration..."
        read -r
    fi
}

# Function to deploy backup schedule
deploy_backup() {
    print_section "DEPLOYING BACKUP SCHEDULE"
    
    print_info "Deploying app namespace backup schedule..."
    
    # Apply the backup schedule
    if oc apply -f "$SCRIPT_DIR/$SCHEDULE_FILE"; then
        print_success "Backup schedule deployed successfully"
    else
        print_error "Failed to deploy backup schedule"
        exit 1
    fi
    
    echo ""
    print_info "Verifying deployment..."
    
    # Check if the schedule was created
    if oc get schedule daily-app-namespace-backup -n $NAMESPACE >/dev/null 2>&1; then
        print_success "Schedule 'daily-app-namespace-backup' created"
        
        # Show schedule details
        print_info "Schedule details:"
        oc get schedule daily-app-namespace-backup -n $NAMESPACE -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule,LAST-BACKUP:.status.lastBackup
    else
        print_error "Schedule was not created properly"
        exit 1
    fi
}

# Function to test backup
test_backup() {
    print_section "TESTING BACKUP FUNCTIONALITY"
    
    read -p "Do you want to create a test backup now? (y/N): " test_now
    if [[ "$test_now" =~ ^[Yy]$ ]]; then
        
        # Ask for namespace to test
        echo ""
        print_info "Enter a namespace to test backup (or press Enter to skip):"
        read -r test_namespace
        
        if [[ -n "$test_namespace" ]]; then
            if oc get namespace "$test_namespace" >/dev/null 2>&1; then
                print_info "Creating test backup for namespace: $test_namespace"
                
                # Create test backup
                cat <<EOF | oc apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: test-backup-$(date +%Y%m%d-%H%M%S)
  namespace: $NAMESPACE
  labels:
    backup-type: test
spec:
  includedNamespaces:
  - $test_namespace
  storageLocation: ocp-prd-backup-location
  volumeSnapshotLocations:
  - ocp-prd-snapshot-location
  includeClusterResources: false
  ttl: 24h0m0s
EOF
                
                print_success "Test backup created. Monitor with: oc get backup -n $NAMESPACE"
            else
                print_error "Namespace '$test_namespace' not found"
            fi
        else
            print_info "Skipping test backup"
        fi
    fi
}

# Function to show monitoring commands
show_monitoring() {
    print_section "MONITORING YOUR BACKUPS"
    
    echo "📊 Use these commands to monitor your backups:"
    echo ""
    echo "# View all backup schedules"
    echo "oc get schedule -n $NAMESPACE"
    echo ""
    echo "# View all backups"
    echo "oc get backup -n $NAMESPACE"
    echo ""
    echo "# View backup details"
    echo "oc describe backup <backup-name> -n $NAMESPACE"
    echo ""
    echo "# View backup logs"
    echo "oc logs -n $NAMESPACE deployment/velero"
    echo ""
    echo "# Check backup storage location status"
    echo "oc get backupstoragelocations -n $NAMESPACE"
    echo ""
    echo "# Monitor backup progress"
    echo "oc get backup -n $NAMESPACE -w"
}

# Function to show restore example
show_restore_example() {
    print_section "RESTORE PROCEDURE"
    
    echo "🔄 To restore from a backup:"
    echo ""
    echo "1. List available backups:"
    echo "   oc get backup -n $NAMESPACE"
    echo ""
    echo "2. Create a restore (example):"
    cat <<'EOF'
   oc create -f - <<YAML
   apiVersion: velero.io/v1
   kind: Restore
   metadata:
     name: restore-$(date +%Y%m%d-%H%M%S)
     namespace: openshift-adp
   spec:
     backupName: <backup-name>
     excludedResources:
     - nodes
     - events
     - events.events.k8s.io
     - backups.velero.io
     - restores.velero.io
     - resticrepositories.velero.io
   YAML
EOF
    echo ""
    echo "3. Monitor restore:"
    echo "   oc get restore -n $NAMESPACE"
    echo "   oc describe restore <restore-name> -n $NAMESPACE"
}

# Main execution
main() {
    check_prerequisites
    show_namespaces
    customize_backup
    deploy_backup
    test_backup
    show_monitoring
    show_restore_example
    
    print_section "SETUP COMPLETE"
    print_success "Daily backup schedule for app namespaces is now configured!"
    echo ""
    print_info "Key points:"
    echo "  • Backups run daily at 3:00 AM"
    echo "  • Backups are stored on ocp-host S3 storage"
    echo "  • Retention period: 30 days"
    echo "  • Monitor with: oc get backup -n $NAMESPACE"
    echo ""
    print_warning "Remember to:"
    echo "  1. Test restore procedure in a non-production environment"
    echo "  2. Monitor backup success regularly"
    echo "  3. Verify storage space on ocp-host"
    echo "  4. Update namespace list as you add new applications"
}

# Run main function
main "$@"
