#!/bin/bash

# OAuth Azure AD SSO Configuration Verification Script
# This script compares the GitOps OAuth configuration with the actual ocp-prd cluster settings

set -e

echo "🔍 OAuth Azure AD SSO Configuration Verification for OCP-PRD"
echo "============================================================="
echo ""

# Check if logged into the correct cluster
CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null || echo "not-logged-in")
EXPECTED_SERVER="https://api.ocp-prd.kohlerco.com:6443"

if [[ "$CURRENT_SERVER" != "$EXPECTED_SERVER" ]]; then
    echo "❌ Error: Not logged into the correct cluster"
    echo "Current: $CURRENT_SERVER"
    echo "Expected: $EXPECTED_SERVER"
    echo ""
    echo "Please login to OCP-PRD cluster first:"
    echo "oc login $EXPECTED_SERVER"
    exit 1
fi

echo "✅ Connected to OCP-PRD cluster"
echo "Server: $CURRENT_SERVER"
echo ""

# Function to get colored status
get_status_color() {
    case $1 in
        "MATCH") echo "✅ $1" ;;
        "MISMATCH") echo "❌ $1" ;;
        "WARNING") echo "⚠️ $1" ;;
        "INFO") echo "ℹ️ $1" ;;
        *) echo "⚪ $1" ;;
    esac
}

echo "📊 Comparing GitOps OAuth Configuration vs Cluster Configuration"
echo "================================================================"

echo ""
echo "1️⃣ OAuth Identity Provider Configuration"
echo "----------------------------------------"

# Check if OAuth configuration exists
OAUTH_EXISTS=$(oc get oauth cluster -o name 2>/dev/null || echo "")
if [[ -z "$OAUTH_EXISTS" ]]; then
    echo "❌ OAuth cluster configuration not found"
    exit 1
fi

# Check identity provider name
CLUSTER_IDP_NAME=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].name}' 2>/dev/null || echo "")
GITOPS_IDP_NAME="azureadsso"

if [[ "$CLUSTER_IDP_NAME" == "$GITOPS_IDP_NAME" ]]; then
    echo "Identity Provider Name: $(get_status_color "MATCH") ($GITOPS_IDP_NAME)"
else
    echo "Identity Provider Name: $(get_status_color "MISMATCH") - GitOps: $GITOPS_IDP_NAME, Cluster: $CLUSTER_IDP_NAME"
fi

# Check identity provider type
CLUSTER_IDP_TYPE=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].type}' 2>/dev/null || echo "")
GITOPS_IDP_TYPE="OpenID"

if [[ "$CLUSTER_IDP_TYPE" == "$GITOPS_IDP_TYPE" ]]; then
    echo "Identity Provider Type: $(get_status_color "MATCH") ($GITOPS_IDP_TYPE)"
else
    echo "Identity Provider Type: $(get_status_color "MISMATCH") - GitOps: $GITOPS_IDP_TYPE, Cluster: $CLUSTER_IDP_TYPE"
fi

# Check mapping method
CLUSTER_MAPPING_METHOD=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].mappingMethod}' 2>/dev/null || echo "")
GITOPS_MAPPING_METHOD="claim"

if [[ "$CLUSTER_MAPPING_METHOD" == "$GITOPS_MAPPING_METHOD" ]]; then
    echo "Mapping Method: $(get_status_color "MATCH") ($GITOPS_MAPPING_METHOD)"
else
    echo "Mapping Method: $(get_status_color "MISMATCH") - GitOps: $GITOPS_MAPPING_METHOD, Cluster: $CLUSTER_MAPPING_METHOD"
fi

echo ""
echo "2️⃣ Azure AD OpenID Configuration"
echo "--------------------------------"

# Check client ID
CLUSTER_CLIENT_ID=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].openID.clientID}' 2>/dev/null || echo "")
GITOPS_CLIENT_ID="667e7b9c-e03e-4967-a9fd-953fef9cbce6"

if [[ "$CLUSTER_CLIENT_ID" == "$GITOPS_CLIENT_ID" ]]; then
    echo "Client ID: $(get_status_color "MATCH") ($GITOPS_CLIENT_ID)"
else
    echo "Client ID: $(get_status_color "MISMATCH") - GitOps: $GITOPS_CLIENT_ID, Cluster: $CLUSTER_CLIENT_ID"
fi

# Check issuer URL
CLUSTER_ISSUER=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].openID.issuer}' 2>/dev/null || echo "")
GITOPS_ISSUER="https://login.microsoftonline.com/5d2d3f03-286e-4643-8f5b-10565608e5f8"

if [[ "$CLUSTER_ISSUER" == "$GITOPS_ISSUER" ]]; then
    echo "Issuer URL: $(get_status_color "MATCH") ($GITOPS_ISSUER)"
else
    echo "Issuer URL: $(get_status_color "MISMATCH") - GitOps: $GITOPS_ISSUER, Cluster: $CLUSTER_ISSUER"
fi

# Extract tenant ID from issuer
CLUSTER_TENANT_ID=$(echo "$CLUSTER_ISSUER" | sed 's|.*microsoftonline.com/||')
GITOPS_TENANT_ID="5d2d3f03-286e-4643-8f5b-10565608e5f8"

if [[ "$CLUSTER_TENANT_ID" == "$GITOPS_TENANT_ID" ]]; then
    echo "Azure AD Tenant ID: $(get_status_color "MATCH") ($GITOPS_TENANT_ID)"
else
    echo "Azure AD Tenant ID: $(get_status_color "MISMATCH") - GitOps: $GITOPS_TENANT_ID, Cluster: $CLUSTER_TENANT_ID"
fi

echo ""
echo "3️⃣ Claims Configuration"
echo "-----------------------"

# Check email claim
CLUSTER_EMAIL_CLAIM=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].openID.claims.email[0]}' 2>/dev/null || echo "")
GITOPS_EMAIL_CLAIM="email"

if [[ "$CLUSTER_EMAIL_CLAIM" == "$GITOPS_EMAIL_CLAIM" ]]; then
    echo "Email Claim: $(get_status_color "MATCH") ($GITOPS_EMAIL_CLAIM)"
else
    echo "Email Claim: $(get_status_color "MISMATCH") - GitOps: $GITOPS_EMAIL_CLAIM, Cluster: $CLUSTER_EMAIL_CLAIM"
fi

# Check name claim
CLUSTER_NAME_CLAIM=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].openID.claims.name[0]}' 2>/dev/null || echo "")
GITOPS_NAME_CLAIM="name"

if [[ "$CLUSTER_NAME_CLAIM" == "$GITOPS_NAME_CLAIM" ]]; then
    echo "Name Claim: $(get_status_color "MATCH") ($GITOPS_NAME_CLAIM)"
else
    echo "Name Claim: $(get_status_color "MISMATCH") - GitOps: $GITOPS_NAME_CLAIM, Cluster: $CLUSTER_NAME_CLAIM"
fi

# Check preferred username claim
CLUSTER_USERNAME_CLAIM=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].openID.claims.preferredUsername[0]}' 2>/dev/null || echo "")
GITOPS_USERNAME_CLAIM="upn"

if [[ "$CLUSTER_USERNAME_CLAIM" == "$GITOPS_USERNAME_CLAIM" ]]; then
    echo "Preferred Username Claim: $(get_status_color "MATCH") ($GITOPS_USERNAME_CLAIM)"
else
    echo "Preferred Username Claim: $(get_status_color "MISMATCH") - GitOps: $GITOPS_USERNAME_CLAIM, Cluster: $CLUSTER_USERNAME_CLAIM"
fi

echo ""
echo "4️⃣ Client Secret Configuration"
echo "------------------------------"

# Check client secret reference
CLUSTER_SECRET_NAME=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[0].openID.clientSecret.name}' 2>/dev/null || echo "")
GITOPS_SECRET_NAME="openid-client-secret-azuread"

echo "Current Secret Name: $CLUSTER_SECRET_NAME"
echo "GitOps Secret Name: $GITOPS_SECRET_NAME"

# Note about secret name difference
if [[ "$CLUSTER_SECRET_NAME" != "$GITOPS_SECRET_NAME" ]]; then
    echo "Secret Name: $(get_status_color "INFO") Different names - Current: $CLUSTER_SECRET_NAME, GitOps: $GITOPS_SECRET_NAME"
    echo "  $(get_status_color "INFO") This is expected as GitOps will create a new secret with a consistent name"
else
    echo "Secret Name: $(get_status_color "MATCH") ($GITOPS_SECRET_NAME)"
fi

# Check if current secret exists
if oc get secret "$CLUSTER_SECRET_NAME" -n openshift-config >/dev/null 2>&1; then
    echo "Current Secret Status: $(get_status_color "MATCH") (Secret exists in openshift-config)"
else
    echo "Current Secret Status: $(get_status_color "WARNING") (Secret not found)"
fi

echo ""
echo "5️⃣ OAuth Authentication Status"
echo "------------------------------"

# Check OAuth operator status
OAUTH_OPERATOR_STATUS=$(oc get clusteroperator authentication -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
if [[ "$OAUTH_OPERATOR_STATUS" == "True" ]]; then
    echo "OAuth Operator: $(get_status_color "MATCH") (Available)"
else
    echo "OAuth Operator: $(get_status_color "WARNING") (Status: $OAUTH_OPERATOR_STATUS)"
fi

# Check OAuth pods
OAUTH_PODS_READY=$(oc get pods -n openshift-authentication -l app=oauth-openshift --no-headers 2>/dev/null | grep -c "Running" || echo "0")
OAUTH_PODS_TOTAL=$(oc get pods -n openshift-authentication -l app=oauth-openshift --no-headers 2>/dev/null | wc -l || echo "0")

if [[ "$OAUTH_PODS_READY" -gt 0 ]] && [[ "$OAUTH_PODS_READY" == "$OAUTH_PODS_TOTAL" ]]; then
    echo "OAuth Pods: $(get_status_color "MATCH") ($OAUTH_PODS_READY/$OAUTH_PODS_TOTAL running)"
else
    echo "OAuth Pods: $(get_status_color "WARNING") ($OAUTH_PODS_READY/$OAUTH_PODS_TOTAL running)"
fi

echo ""
echo "📋 Overall Assessment"
echo "====================="

# Count matches vs mismatches
TOTAL_CHECKS=8
MATCHES=0

# Re-run key checks for counting
[[ "$CLUSTER_IDP_NAME" == "$GITOPS_IDP_NAME" ]] && ((MATCHES++))
[[ "$CLUSTER_IDP_TYPE" == "$GITOPS_IDP_TYPE" ]] && ((MATCHES++))
[[ "$CLUSTER_MAPPING_METHOD" == "$GITOPS_MAPPING_METHOD" ]] && ((MATCHES++))
[[ "$CLUSTER_CLIENT_ID" == "$GITOPS_CLIENT_ID" ]] && ((MATCHES++))
[[ "$CLUSTER_ISSUER" == "$GITOPS_ISSUER" ]] && ((MATCHES++))
[[ "$CLUSTER_EMAIL_CLAIM" == "$GITOPS_EMAIL_CLAIM" ]] && ((MATCHES++))
[[ "$CLUSTER_NAME_CLAIM" == "$GITOPS_NAME_CLAIM" ]] && ((MATCHES++))
[[ "$CLUSTER_USERNAME_CLAIM" == "$GITOPS_USERNAME_CLAIM" ]] && ((MATCHES++))

MATCH_PERCENTAGE=$((MATCHES * 100 / TOTAL_CHECKS))

echo "Configuration Match: $MATCHES/$TOTAL_CHECKS checks passed ($MATCH_PERCENTAGE%)"

if [ $MATCHES -eq $TOTAL_CHECKS ]; then
    echo "🎉 All OAuth configurations match! GitOps repository is aligned with ocp-prd cluster."
elif [ $MATCHES -ge $((TOTAL_CHECKS * 3 / 4)) ]; then
    echo "✅ Most OAuth configurations match. Minor discrepancies are acceptable."
else
    echo "⚠️ Several OAuth configuration mismatches detected. Review and update GitOps repository."
fi

echo ""
echo "🔧 Configuration Summary"
echo "========================"
echo "Azure AD Tenant: Kohler Co (ID: $CLUSTER_TENANT_ID)"
echo "Application ID: $CLUSTER_CLIENT_ID"
echo "Identity Provider: $CLUSTER_IDP_NAME"
echo "Authentication Status: $OAUTH_OPERATOR_STATUS"

echo ""
echo "📝 Next Steps"
echo "============="
if [[ "$CLUSTER_SECRET_NAME" != "$GITOPS_SECRET_NAME" ]]; then
    echo "1. Update client secret in GitOps deployment:"
    echo "   oc get secret $CLUSTER_SECRET_NAME -n openshift-config -o jsonpath='{.data.clientSecret}' | base64 -d"
    echo "   # Use this value to update the GitOps secret"
    echo ""
fi
echo "2. Test OAuth authentication after GitOps deployment"
echo "3. Verify user login and claims mapping"
echo "4. Configure RBAC permissions for authenticated users"

echo ""
echo "🔍 Useful Commands"
echo "=================="
echo "# Test authentication"
echo "oc get users"
echo "oc get identities"
echo ""
echo "# Check OAuth logs"
echo "oc logs -n openshift-authentication deployment/oauth-openshift"
echo ""
echo "# OAuth operator status"
echo "oc get clusteroperator authentication"
