#!/bin/bash

# Helper script to extract and update Azure AD client secret

echo "🔐 Azure AD Client Secret Management Helper"
echo "==========================================="
echo ""

# Check if logged into cluster
CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null || echo "not-logged-in")
if [[ "$CURRENT_SERVER" == "not-logged-in" ]]; then
    echo "❌ Error: Not logged into any OpenShift cluster"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

echo "📱 Connected to cluster: $CURRENT_SERVER"
echo ""

# Function to extract current secret
extract_current_secret() {
    echo "🔍 Extracting current Azure AD client secret from cluster..."
    
    # Find the current secret name
    CURRENT_SECRET_NAME=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].openID.clientSecret.name}' 2>/dev/null)
    
    if [[ -z "$CURRENT_SECRET_NAME" ]]; then
        echo "❌ Could not find OAuth client secret reference"
        return 1
    fi
    
    echo "📋 Current secret name: $CURRENT_SECRET_NAME"
    
    # Extract the secret value
    SECRET_VALUE=$(oc get secret "$CURRENT_SECRET_NAME" -n openshift-config -o jsonpath='{.data.clientSecret}' 2>/dev/null | base64 -d)
    
    if [[ -z "$SECRET_VALUE" ]]; then
        echo "❌ Could not extract secret value"
        return 1
    fi
    
    echo "✅ Secret extracted successfully"
    echo ""
    echo "🔑 Azure AD Client Secret:"
    echo "------------------------"
    echo "$SECRET_VALUE"
    echo ""
    echo "📝 Instructions:"
    echo "1. Copy the secret value above"
    echo "2. Update the GitOps secret file: components/oauth-configuration/azure-ad-client-secret.yaml"
    echo "3. Replace 'REPLACE_WITH_ACTUAL_AZURE_AD_CLIENT_SECRET' with the actual secret value"
    echo "4. Commit and deploy the GitOps configuration"
    
    return 0
}

# Function to create/update GitOps secret
update_gitops_secret() {
    local secret_value="$1"
    
    if [[ -z "$secret_value" ]]; then
        echo "❌ No secret value provided"
        return 1
    fi
    
    echo "🔄 Creating GitOps-compatible secret..."
    
    # Create the secret with GitOps naming
    oc create secret generic openid-client-secret-azuread \
        --from-literal=clientSecret="$secret_value" \
        --namespace=openshift-config \
        --dry-run=client -o yaml > /tmp/oauth-secret-gitops.yaml
    
    echo "✅ GitOps secret manifest created: /tmp/oauth-secret-gitops.yaml"
    echo ""
    echo "📝 You can apply this manually with:"
    echo "oc apply -f /tmp/oauth-secret-gitops.yaml"
}

# Function to test OAuth configuration
test_oauth_config() {
    echo "🧪 Testing OAuth configuration..."
    echo ""
    
    # Check OAuth operator status
    OAUTH_STATUS=$(oc get clusteroperator authentication -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
    echo "OAuth Operator Status: $OAUTH_STATUS"
    
    # Check OAuth pods
    echo "OAuth Pods:"
    oc get pods -n openshift-authentication -l app=oauth-openshift
    
    echo ""
    echo "🌐 OAuth Endpoint:"
    OAUTH_URL=$(oc get route oauth-openshift -n openshift-authentication -o jsonpath='{.spec.host}' 2>/dev/null)
    if [[ -n "$OAUTH_URL" ]]; then
        echo "https://$OAUTH_URL"
    else
        echo "OAuth route not found"
    fi
}

# Main menu
case "${1:-help}" in
    "extract")
        extract_current_secret
        ;;
    "update")
        if [[ -n "$2" ]]; then
            update_gitops_secret "$2"
        else
            echo "❌ Usage: $0 update <secret-value>"
            exit 1
        fi
        ;;
    "test")
        test_oauth_config
        ;;
    "help"|*)
        echo "🔐 Azure AD Client Secret Management Helper"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  extract  - Extract current client secret from cluster"
        echo "  update   - Create GitOps secret with provided value"
        echo "  test     - Test OAuth configuration and status"
        echo "  help     - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 extract"
        echo "  $0 update 'your-secret-value-here'"
        echo "  $0 test"
        ;;
esac
