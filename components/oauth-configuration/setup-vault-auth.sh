#!/bin/bash
# Setup Vault authentication for OAuth configuration
# This script configures Vault to allow the OAuth service account to access secrets
#
# Before running this script, set the VAULT_ROOT_TOKEN environment variable:
# export VAULT_ROOT_TOKEN="your-vault-root-token-here"

set -e

echo "🔐 Setting up Vault authentication for OAuth configuration..."

# Check if VAULT_ROOT_TOKEN is set
if [ -z "$VAULT_ROOT_TOKEN" ]; then
    echo "❌ VAULT_ROOT_TOKEN environment variable is not set"
    echo "Please set it with: export VAULT_ROOT_TOKEN=\"your-vault-root-token-here\""
    exit 1
fi

# Check if we can access Vault
if ! oc get pod -n vault-system -l app=vault --no-headers | grep -q Running; then
    echo "❌ Vault pod is not running. Please ensure Vault is deployed and running."
    exit 1
fi

# Get the Vault pod name
VAULT_POD=$(oc get pod -n vault-system -l app=vault --no-headers | grep Running | awk '{print $1}')

if [ -z "$VAULT_POD" ]; then
    echo "❌ Could not find running Vault pod"
    exit 1
fi

echo "✅ Found Vault pod: $VAULT_POD"

# Create a more restrictive policy for OAuth access
echo "📋 Creating OAuth-specific Vault policy..."
oc exec $VAULT_POD -n vault-system -- sh -c 'export VAULT_TOKEN=$VAULT_ROOT_TOKEN && vault policy write oauth-policy - << EOF
path "cluster-secrets/openid-client-secret-azuread" {
  capabilities = ["read"]
}
EOF'

# Create a Kubernetes role specifically for OAuth
echo "🔑 Creating Kubernetes role for OAuth..."
oc exec $VAULT_POD -n vault-system -- sh -c 'export VAULT_TOKEN=$VAULT_ROOT_TOKEN && vault write auth/kubernetes/role/oauth-role bound_service_account_names=oauth-vault-auth bound_service_account_namespaces=openshift-config policies=oauth-policy ttl=1h'

echo "✅ Vault authentication setup complete!"
echo ""
echo "📋 Summary of what was created:"
echo "  - Policy: oauth-policy (read access to Azure AD client secret)"
echo "  - Role: oauth-role (bound to oauth-vault-auth service account)"
echo "  - Scope: openshift-config namespace only"
echo ""
echo "🔍 To verify the setup:"
echo "  - Check Vault policies: vault policy list"
echo "  - Check Kubernetes roles: vault read auth/kubernetes/role/oauth-role"
echo "  - Test authentication from a pod in openshift-config namespace"
