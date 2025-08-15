#!/bin/bash
# Setup Azure AD credentials for Group Sync Operator
# This script helps configure the Azure AD credentials needed for group synchronization

set -e

echo "🔐 Setting up Azure AD credentials for Group Sync Operator..."

# Check if we're connected to the cluster
if ! oc whoami >/dev/null 2>&1; then
    echo "❌ Not connected to OpenShift cluster. Please run 'oc login' first."
    exit 1
fi

echo "✅ Connected to OpenShift cluster"

# Check if the group-sync-operator namespace exists
if ! oc get namespace group-sync-operator >/dev/null 2>&1; then
    echo "⚠️  group-sync-operator namespace doesn't exist yet. It will be created when the component is deployed."
    echo "   You can run this script again after the component is deployed."
    exit 0
fi

echo "✅ group-sync-operator namespace exists"

# Azure AD Application Details
AZURE_TENANT_ID="5d2d3f03-286e-4643-8f5b-10565608e6"
AZURE_CLIENT_ID="667e7b9c-e03e-4967-a9fd-953fef9cbce6"

echo ""
echo "📋 Azure AD Application Details:"
echo "  Tenant ID: $AZURE_TENANT_ID"
echo "  Client ID: $AZURE_CLIENT_ID"
echo ""

# Prompt for client secret
read -s -p "🔑 Enter the Azure AD Client Secret: " AZURE_CLIENT_SECRET
echo ""

if [ -z "$AZURE_CLIENT_SECRET" ]; then
    echo "❌ Client secret cannot be empty"
    exit 1
fi

echo "📝 Creating Azure AD credentials secret..."

# Create the secret
oc create secret generic azure-ad-credentials \
  --from-literal=clientSecret="$AZURE_CLIENT_SECRET" \
  --from-literal=tenantId="$AZURE_TENANT_ID" \
  --from-literal=clientId="$AZURE_CLIENT_ID" \
  -n group-sync-operator \
  --dry-run=client -o yaml | oc apply -f -

echo "✅ Azure AD credentials secret created successfully!"

echo ""
echo "🔍 Verifying secret creation..."
oc get secret azure-ad-credentials -n group-sync-operator

echo ""
echo "📋 Next Steps:"
echo "1. Ensure the Group Sync Operator component is deployed via ArgoCD"
echo "2. Check operator status: oc get pods -n group-sync-operator"
echo "3. Monitor group synchronization: oc get groupsync -n group-sync-operator"
echo "4. Check synchronized groups: oc get groups"
echo ""
echo "🔐 Note: The client secret is now stored in the cluster. Consider using Vault for enhanced security."
echo ""
echo "✅ Setup complete!"
