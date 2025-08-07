#!/bin/bash

# Script to connect Kohler OpenShift repository to the cluster
# This script sets up the ArgoCD applications to manage the kohler-openshift repository

set -e

# Configuration variables
GITOPS_REPO="https://github.com/kohler-openshift/kohler-openshift.git"
CLUSTER_NAME="${CLUSTER_NAME:-hub}"
NAMESPACE="openshift-gitops"

echo "🚀 Connecting Kohler OpenShift repository to cluster..."

# Check if we're logged into the cluster
if ! oc whoami &>/dev/null; then
    echo "❌ Error: You must be logged into an OpenShift cluster"
    exit 1
fi

# Check if ArgoCD is installed
if ! oc get ns openshift-gitops &>/dev/null; then
    echo "❌ Error: openshift-gitops namespace not found. Please install OpenShift GitOps operator first."
    exit 1
fi

# Get cluster information
CLUSTER_BASE_DOMAIN=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
PLATFORM_BASE_DOMAIN=${CLUSTER_BASE_DOMAIN#*.}

echo "📋 Configuration:"
echo "   GitOps Repository: $GITOPS_REPO"
echo "   Cluster Name: $CLUSTER_NAME"  
echo "   Cluster Base Domain: $CLUSTER_BASE_DOMAIN"
echo "   Platform Base Domain: $PLATFORM_BASE_DOMAIN"

# Export variables for envsubst
export gitops_repo="$GITOPS_REPO"
export cluster_name="$CLUSTER_NAME"
export cluster_base_domain="$CLUSTER_BASE_DOMAIN"
export platform_base_domain="$PLATFORM_BASE_DOMAIN"

echo "📦 Applying bootstrap configurations..."

# Apply bootstrap configurations in order
echo "   → Applying namespace configuration..."
oc apply -f .bootstrap/0.namespace.yaml

echo "   → Applying subscription..."
oc apply -f .bootstrap/subscription.yaml

echo "   → Applying operator group..."
oc apply -f .bootstrap/2.operatorgroup.yaml

echo "   → Applying cluster role binding..."
oc apply -f .bootstrap/2.cluster-rolebinding.yaml

echo "   → Waiting for OpenShift GitOps to be ready..."
sleep 60

echo "   → Applying ArgoCD configuration..."
envsubst < .bootstrap/argocd.yaml | oc apply -f -

echo "   → Waiting for ArgoCD to be ready..."
sleep 30

echo "   → Applying root application..."
envsubst < .bootstrap/3.root-application.yaml | oc apply -f -

echo "   → Applying Kohler OpenShift connection..."
oc apply -f .bootstrap/4.kohler-openshift-connection.yaml

echo "✅ Kohler OpenShift repository successfully connected to cluster!"
echo ""
echo "🔍 You can monitor the deployment status with:"
echo "   oc get applications -n openshift-gitops"
echo ""
echo "🌐 Access ArgoCD UI at:"
echo "   https://openshift-gitops-server-openshift-gitops.apps.$CLUSTER_BASE_DOMAIN"
echo ""
echo "🔑 Get ArgoCD admin password with:"
echo "   oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=- --keys=admin.password"
