#!/bin/bash

# Simple Bootstrap Deployment Script
# This script applies all YAML files in the .bootstrap folder in numerical order

set -e

BOOTSTRAP_DIR=".bootstrap"

echo "Deploying OpenShift GitOps Bootstrap..."

# Check if oc is available and user is logged in
if ! command -v oc &> /dev/null; then
    echo "Error: oc command not found. Please install OpenShift CLI."
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "Error: Not logged into OpenShift cluster. Please run 'oc login' first."
    exit 1
fi

echo "Logged in as: $(oc whoami)"
echo "Target server: $(oc whoami --show-server)"

# Apply all YAML files in order
for file in $(find "$BOOTSTRAP_DIR" -name "*.yaml" -o -name "*.yml" | sort); do
    filename=$(basename "$file")
    echo "Applying $filename..."
    oc apply -f "$file"
    
    # Add small delays for critical resources
    case "$filename" in
        "0.namespace.yaml")
            echo "Waiting for namespace to be created..."
            sleep 10
            ;;
        "2.subscription.yaml")
            echo "Waiting for operator installation..."
            sleep 60
            ;;
        "4.argocd.yaml")
            echo "Waiting for ArgoCD to initialize..."
            sleep 30
            ;;
    esac
done

echo "Bootstrap deployment completed!"
echo ""
echo "You can check the status with:"
echo "  oc get pods -n openshift-gitops"
echo "  oc get applications -n openshift-gitops"

# Try to show ArgoCD route if available
if oc get route openshift-gitops-server -n openshift-gitops &> /dev/null; then
    ARGOCD_URL=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
    echo "  ArgoCD UI: https://$ARGOCD_URL"
fi
