#!/bin/bash

# GitHub Secrets Setup and Migration Script
# This script helps migrate from plaintext secrets to secure secret management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-ocp-dev}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
VAULT_ADDR="${VAULT_ADDR:-}"
GITHUB_REPO="${GITHUB_REPO:-kohler-co/kohler-openshift}"

echo -e "${BLUE}🔐 Kohler OpenShift - GitHub Secrets Setup Script${NC}"
echo "=================================================="

# Function to print status messages
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if oc is installed and logged in
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed"
        exit 1
    fi
    
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift cluster"
        exit 1
    fi
    
    print_status "OpenShift CLI available and logged in as: $(oc whoami)"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed - some features may not work"
    fi
    
    # Check if gh CLI is available
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            print_status "GitHub CLI available and authenticated"
        else
            print_warning "GitHub CLI is not authenticated"
        fi
    else
        print_warning "GitHub CLI is not installed - manual secret setup required"
    fi
}

# Function to extract current secrets from cluster
extract_current_secrets() {
    print_info "Extracting current secrets from cluster..."
    
    SECRETS_DIR="$PROJECT_ROOT/extracted-secrets"
    mkdir -p "$SECRETS_DIR"
    
    # Extract Azure AD client secret
    if oc get secret openid-client-secret-azuread -n openshift-config &> /dev/null; then
        AZURE_SECRET=$(oc get secret openid-client-secret-azuread -n openshift-config -o jsonpath='{.data.clientSecret}' | base64 -d)
        echo "AZURE_AD_CLIENT_SECRET=$AZURE_SECRET" >> "$SECRETS_DIR/github-secrets.env"
        print_status "Extracted Azure AD client secret"
    else
        print_warning "Azure AD client secret not found in cluster"
    fi
    
    # Extract OADP backup credentials
    if oc get secret cloud-credentials -n openshift-adp &> /dev/null; then
        CLOUD_CREDS=$(oc get secret cloud-credentials -n openshift-adp -o jsonpath='{.data.cloud}' | base64 -d)
        AWS_ACCESS_KEY=$(echo "$CLOUD_CREDS" | grep aws_access_key_id | cut -d'=' -f2)
        AWS_SECRET_KEY=$(echo "$CLOUD_CREDS" | grep aws_secret_access_key | cut -d'=' -f2)
        
        echo "OADP_AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY" >> "$SECRETS_DIR/github-secrets.env"
        echo "OADP_AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY" >> "$SECRETS_DIR/github-secrets.env"
        print_status "Extracted OADP backup credentials"
    else
        print_warning "OADP backup credentials not found in cluster"
    fi
    
    # Get cluster information
    CLUSTER_SERVER=$(oc whoami --show-server)
    CLUSTER_TOKEN=$(oc whoami --show-token)
    
    echo "OPENSHIFT_SERVER=$CLUSTER_SERVER" >> "$SECRETS_DIR/github-secrets.env"
    echo "OPENSHIFT_TOKEN=$CLUSTER_TOKEN" >> "$SECRETS_DIR/github-secrets.env"
    
    print_status "Secrets extracted to: $SECRETS_DIR/github-secrets.env"
    print_warning "⚠️  IMPORTANT: This file contains sensitive data - do not commit to Git!"
}

# Function to set up GitHub secrets automatically
setup_github_secrets() {
    print_info "Setting up GitHub secrets..."
    
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI is required for automatic secret setup"
        print_info "Please install gh CLI or set up secrets manually"
        return 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        print_info "Run: gh auth login"
        return 1
    fi
    
    SECRETS_FILE="$PROJECT_ROOT/extracted-secrets/github-secrets.env"
    
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file not found. Run extract_current_secrets first."
        return 1
    fi
    
    print_info "Setting GitHub repository secrets..."
    
    # Read secrets from file and set them in GitHub
    while IFS='=' read -r key value; do
        if [[ $key =~ ^[A-Z_]+$ ]] && [[ -n $value ]]; then
            echo "Setting secret: $key"
            echo "$value" | gh secret set "$key" --repo "$GITHUB_REPO"
        fi
    done < "$SECRETS_FILE"
    
    print_status "GitHub secrets configured"
}

# Function to install Sealed Secrets controller
install_sealed_secrets() {
    print_info "Installing Sealed Secrets controller..."
    
    if oc get namespace sealed-secrets-system &> /dev/null; then
        print_warning "Sealed Secrets controller already installed"
        return 0
    fi
    
    # Install Sealed Secrets controller
    oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
    
    # Wait for deployment to be ready
    print_info "Waiting for Sealed Secrets controller to be ready..."
    oc wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets-system
    
    print_status "Sealed Secrets controller installed"
}

# Function to extract and set up kubeseal certificate
setup_kubeseal_cert() {
    print_info "Setting up kubeseal certificate..."
    
    # Wait for the sealed secrets controller to generate the certificate
    sleep 10
    
    # Extract the public certificate
    CERT_FILE="$PROJECT_ROOT/extracted-secrets/kubeseal-cert.pem"
    oc get secret -n sealed-secrets-system sealed-secrets-key -o jsonpath='{.data.tls\.crt}' | base64 -d > "$CERT_FILE"
    
    # Set as GitHub secret if gh CLI is available
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        cat "$CERT_FILE" | gh secret set KUBESEAL_CERT --repo "$GITHUB_REPO"
        print_status "Kubeseal certificate set as GitHub secret"
    else
        print_warning "Manual setup required for KUBESEAL_CERT GitHub secret"
        print_info "Certificate saved to: $CERT_FILE"
    fi
}

# Function to generate initial sealed secrets
generate_sealed_secrets() {
    print_info "Generating sealed secrets..."
    
    if ! command -v kubeseal &> /dev/null; then
        print_warning "kubeseal CLI not found - installing..."
        
        # Download and install kubeseal
        KUBESEAL_VERSION="0.24.0"
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
        tar -xzf "kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
        
        # Move to a location in PATH or use directly
        if [ -w "/usr/local/bin" ]; then
            sudo mv kubeseal /usr/local/bin/
        else
            mv kubeseal "$PROJECT_ROOT/kubeseal"
            export PATH="$PROJECT_ROOT:$PATH"
        fi
        
        cd - &> /dev/null
        rm -rf "$TEMP_DIR"
    fi
    
    CERT_FILE="$PROJECT_ROOT/extracted-secrets/kubeseal-cert.pem"
    SECRETS_FILE="$PROJECT_ROOT/extracted-secrets/github-secrets.env"
    
    if [ ! -f "$CERT_FILE" ]; then
        print_error "Kubeseal certificate not found"
        return 1
    fi
    
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file not found"
        return 1
    fi
    
    # Generate sealed secret for Azure AD
    if grep -q "AZURE_AD_CLIENT_SECRET" "$SECRETS_FILE"; then
        AZURE_SECRET=$(grep "AZURE_AD_CLIENT_SECRET" "$SECRETS_FILE" | cut -d'=' -f2)
        kubectl create secret generic openid-client-secret-azuread \
            --namespace=openshift-config \
            --from-literal=clientSecret="$AZURE_SECRET" \
            --dry-run=client -o yaml | \
        kubeseal --cert "$CERT_FILE" -o yaml > "$PROJECT_ROOT/components/oauth-configuration/azure-ad-client-sealed-secret.yaml"
        
        print_status "Generated sealed secret for Azure AD client"
    fi
    
    # Generate sealed secret for OADP
    if grep -q "OADP_AWS_ACCESS_KEY_ID" "$SECRETS_FILE"; then
        AWS_ACCESS_KEY=$(grep "OADP_AWS_ACCESS_KEY_ID" "$SECRETS_FILE" | cut -d'=' -f2)
        AWS_SECRET_KEY=$(grep "OADP_AWS_SECRET_ACCESS_KEY" "$SECRETS_FILE" | cut -d'=' -f2)
        
        cat > /tmp/cloud-credentials.txt << EOF
[default]
aws_access_key_id=$AWS_ACCESS_KEY
aws_secret_access_key=$AWS_SECRET_KEY
EOF
        
        kubectl create secret generic cloud-credentials \
            --namespace=openshift-adp \
            --from-file=cloud=/tmp/cloud-credentials.txt \
            --dry-run=client -o yaml | \
        kubeseal --cert "$CERT_FILE" -o yaml > "$PROJECT_ROOT/components/oadp-configuration/backup-storage-sealed-secret.yaml"
        
        rm /tmp/cloud-credentials.txt
        print_status "Generated sealed secret for OADP backup credentials"
    fi
}

# Function to validate the setup
validate_setup() {
    print_info "Validating setup..."
    
    # Check if sealed secrets were generated
    if [ -f "$PROJECT_ROOT/components/oauth-configuration/azure-ad-client-sealed-secret.yaml" ]; then
        print_status "Azure AD sealed secret generated"
    else
        print_warning "Azure AD sealed secret not found"
    fi
    
    if [ -f "$PROJECT_ROOT/components/oadp-configuration/backup-storage-sealed-secret.yaml" ]; then
        print_status "OADP sealed secret generated"
    else
        print_warning "OADP sealed secret not found"
    fi
    
    # Check if GitHub workflows exist
    if [ -f "$PROJECT_ROOT/.github/workflows/secrets-management.yml" ]; then
        print_status "Secrets management workflow configured"
    else
        print_warning "Secrets management workflow not found"
    fi
    
    # Validate YAML syntax
    print_info "Validating YAML syntax..."
    find "$PROJECT_ROOT/components" -name "*.yaml" -type f | while read -r file; do
        if ! kubectl --dry-run=client apply -f "$file" --validate=true &> /dev/null; then
            print_error "YAML validation failed for: $file"
        fi
    done
    
    print_status "Setup validation completed"
}

# Function to display manual setup instructions
show_manual_setup() {
    cat << EOF

${BLUE}📋 Manual Setup Instructions${NC}
================================

1. Set up GitHub Repository Secrets:
   Go to: https://github.com/$GITHUB_REPO/settings/secrets/actions
   
   Add the following secrets from: $PROJECT_ROOT/extracted-secrets/github-secrets.env
   
2. If using HashiCorp Vault, also add:
   - VAULT_ADDR: Your Vault server URL
   - VAULT_TOKEN: Vault authentication token (or VAULT_ROLE_ID + VAULT_SECRET_ID)
   
3. Add registry credentials:
   - REGISTRY_USERNAME: Your container registry username
   - REGISTRY_PASSWORD: Your container registry password

4. Set up environment protection rules:
   - Go to Settings → Environments
   - Create: dev, staging, prod
   - Add environment-specific secrets

5. Test the setup:
   - Push changes to trigger GitHub Actions
   - Check workflow runs in the Actions tab

EOF
}

# Main menu
show_menu() {
    echo ""
    echo -e "${BLUE}Choose an option:${NC}"
    echo "1. Full setup (extract secrets + install sealed secrets + setup GitHub)"
    echo "2. Extract current secrets from cluster"
    echo "3. Install Sealed Secrets controller"
    echo "4. Setup GitHub secrets"
    echo "5. Generate sealed secrets"
    echo "6. Validate setup"
    echo "7. Show manual setup instructions"
    echo "8. Exit"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    
    while true; do
        show_menu
        read -p "Enter your choice (1-8): " choice
        
        case $choice in
            1)
                extract_current_secrets
                install_sealed_secrets
                setup_kubeseal_cert
                setup_github_secrets
                generate_sealed_secrets
                validate_setup
                ;;
            2)
                extract_current_secrets
                ;;
            3)
                install_sealed_secrets
                setup_kubeseal_cert
                ;;
            4)
                setup_github_secrets
                ;;
            5)
                generate_sealed_secrets
                ;;
            6)
                validate_setup
                ;;
            7)
                show_manual_setup
                ;;
            8)
                print_info "Exiting..."
                break
                ;;
            *)
                print_error "Invalid choice. Please try again."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run the main function
main "$@"
