#!/bin/bash

# Bootstrap Deployment Script with Better Progress Tracking
set -e

echo "=== OpenShift GitOps Bootstrap Deployment ==="
echo "Timestamp: $(date)"
echo ""

# Check prerequisites
echo "[STEP 1/7] Checking prerequisites..."
if ! command -v oc &> /dev/null; then
    echo "ERROR: oc command not found. Please install OpenShift CLI."
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "ERROR: Not logged into OpenShift cluster. Please run 'oc login' first."
    exit 1
fi

echo "✓ Logged in as: $(oc whoami)"
echo "✓ Target server: $(oc whoami --show-server)"

if [[ ! -d ".bootstrap" ]]; then
    echo "ERROR: Bootstrap directory not found: .bootstrap"
    exit 1
fi
echo "✓ Bootstrap directory found"
echo ""

# Step 2: Create namespace
echo "[STEP 2/7] Creating namespace..."
oc apply -f .bootstrap/0.namespace.yaml
echo "✓ Namespace created/updated"
sleep 5
echo ""

# Step 3: Create OperatorGroup (cluster-wide only)
echo "[STEP 3/7] Creating OperatorGroup..."
oc apply -f .bootstrap/1.operatorgroup.clusterwide.yaml
echo "✓ OperatorGroup created/updated"
sleep 5
echo ""

# Step 4: Create Subscription
echo "[STEP 4/7] Installing OpenShift GitOps Operator..."
oc apply -f .bootstrap/2.subscription.yaml
echo "✓ Subscription created"
echo "Waiting for operator to install (this may take a few minutes)..."

# Wait for CSV to be ready
for i in {1..60}; do
    if oc get csv -n openshift-gitops-operator 2>/dev/null | grep -q "openshift-gitops-operator.*Succeeded"; then
        echo "✓ Operator installed successfully"
        break
    fi
    if [[ $i -eq 60 ]]; then
        echo "WARNING: Operator installation taking longer than expected"
        echo "Current CSV status:"
        oc get csv -n openshift-gitops-operator
        break
    fi
    echo "  Waiting... ($i/60)"
    sleep 10
done

# Wait for openshift-gitops namespace to be created by the operator
echo "Waiting for openshift-gitops namespace to be created..."
for i in {1..30}; do
    if oc get namespace openshift-gitops &> /dev/null; then
        echo "✓ openshift-gitops namespace created"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "WARNING: openshift-gitops namespace not found"
        break
    fi
    sleep 10
done
echo ""

# Step 5: Create ClusterRoleBinding
echo "[STEP 5/7] Creating ClusterRoleBinding..."
oc apply -f .bootstrap/3.cluster-rolebinding.yaml
echo "✓ ClusterRoleBinding created/updated"
echo ""

# Step 6: Deploy ArgoCD
echo "[STEP 6/7] Deploying ArgoCD instance..."
oc apply -f .bootstrap/4.argocd.yaml
echo "✓ ArgoCD configuration applied"
echo "Waiting for ArgoCD to be ready..."

for i in {1..30}; do
    if oc get argocd openshift-gitops -n openshift-gitops &> /dev/null; then
        echo "✓ ArgoCD instance created"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "WARNING: ArgoCD instance not ready"
        break
    fi
    sleep 10
done
echo ""

# Step 7: Create Repository Secret and Root Application
echo "[STEP 7/7] Finalizing configuration..."
oc apply -f .bootstrap/5.repository-secret.yaml
echo "✓ Repository secret created/updated"

oc apply -f .bootstrap/6.root-application.yaml
echo "✓ Root ApplicationSet created/updated"
echo ""

# Final status check
echo "=== Deployment Summary ==="
echo ""
echo "Checking final status:"

echo -n "• Namespace openshift-gitops-operator: "
if oc get namespace openshift-gitops-operator &> /dev/null; then
    echo "✓ EXISTS"
else
    echo "✗ MISSING"
fi

echo -n "• Namespace openshift-gitops: "
if oc get namespace openshift-gitops &> /dev/null; then
    echo "✓ EXISTS"
else
    echo "✗ MISSING"
fi

echo -n "• GitOps Operator CSV: "
if oc get csv -n openshift-gitops-operator 2>/dev/null | grep -q "openshift-gitops-operator.*Succeeded"; then
    echo "✓ READY"
else
    echo "⚠ NOT READY"
fi

echo -n "• ArgoCD instance: "
if oc get argocd openshift-gitops -n openshift-gitops &> /dev/null; then
    echo "✓ EXISTS"
else
    echo "✗ MISSING"
fi

echo -n "• Root ApplicationSet: "
if oc get applicationset root-applications -n openshift-gitops &> /dev/null; then
    echo "✓ EXISTS"
else
    echo "✗ MISSING"
fi

# Show ArgoCD URL if available
ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [[ -n "$ARGOCD_ROUTE" ]]; then
    echo ""
    echo "🎉 ArgoCD UI available at: https://$ARGOCD_ROUTE"
fi

echo ""
echo "=== Bootstrap Deployment Complete ==="
echo "Timestamp: $(date)"
echo ""
echo "Next steps:"
echo "1. Wait a few minutes for all pods to start"
echo "2. Check pod status: oc get pods -n openshift-gitops"
echo "3. Access ArgoCD UI with your OpenShift credentials"
echo "4. Verify Applications are syncing properly"
