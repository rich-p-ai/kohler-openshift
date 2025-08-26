#!/bin/bash

# Migration Starter Script for ocp-prd → ocp2
# This script starts the migration process using the migration plan

set -e

echo "🚀 Starting Migration: ocp-prd → ocp2"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking migration prerequisites..."
    
    # Check if we're in the right namespace
    CURRENT_NS=$(oc project -q)
    if [[ "$CURRENT_NS" != "openshift-migration" ]]; then
        print_status "Switching to openshift-migration namespace..."
        oc project openshift-migration
    fi
    
    # Check migration clusters
    print_status "Checking migration clusters..."
    if ! oc get migcluster ocp-prd-source-cluster -n openshift-migration &>/dev/null; then
        print_error "Source cluster not found. Run setup first."
        exit 1
    fi
    
    if ! oc get migcluster ocp2-target-cluster -n openshift-migration &>/dev/null; then
        print_error "Target cluster not found. Run setup first."
        exit 1
    fi
    
    # Check migration storage
    if ! oc get migstorage migration-storage -n openshift-migration &>/dev/null; then
        print_error "Migration storage not found. Run setup first."
        exit 1
    fi
    
    # Check migration plan
    if ! oc get migplan ocp-prd-to-ocp2-migration -n openshift-migration &>/dev/null; then
        print_error "Migration plan not found. Run setup first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Start migration
start_migration() {
    print_status "Starting migration execution..."
    
    # Create migration
    cat <<EOF | oc create -f -
apiVersion: migration.openshift.io/v1alpha1
kind: MigMigration
metadata:
  name: ocp-prd-to-ocp2-migration
  namespace: openshift-migration
spec:
  migPlanRef:
    name: ocp-prd-to-ocp2-migration
  stage: true
EOF
    
    if [[ $? -eq 0 ]]; then
        print_success "Migration started successfully"
    else
        print_error "Failed to start migration"
        exit 1
    fi
}

# Show monitoring commands
show_monitoring_commands() {
    echo ""
    echo "======================================"
    echo "🎯 Migration Started Successfully!"
    echo "======================================"
    echo ""
    echo "📊 Monitor Migration Progress:"
    echo "  oc get migmigration -n openshift-migration -w"
    echo ""
    echo "🔍 Check Detailed Status:"
    echo "  oc describe migmigration ocp-prd-to-ocp2-migration -n openshift-migration"
    echo ""
    echo "📋 View Migration Logs:"
    echo "  oc logs -f deployment/migration-controller -n openshift-migration"
    echo ""
    echo "📚 Full Documentation:"
    echo "  See MIGRATION-EXECUTION-GUIDE.md for detailed instructions"
    echo ""
}

# Main execution
main() {
    echo "Starting migration process..."
    echo ""
    
    check_prerequisites
    echo ""
    
    start_migration
    echo ""
    
    show_monitoring_commands
}

# Run main function
main "$@"
