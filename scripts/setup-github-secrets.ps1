# GitHub Secrets Setup and Migration Script for Windows
# PowerShell version of the setup script

param(
    [Parameter(HelpMessage="Target environment (dev, staging, prod)")]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(HelpMessage="GitHub repository in format owner/repo")]
    [string]$GitHubRepo = "kohler-co/kohler-openshift",
    
    [Parameter(HelpMessage="Vault server address")]
    [string]$VaultAddr = $env:VAULT_ADDR
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "🔐 Kohler OpenShift - GitHub Secrets Setup Script" -ForegroundColor $Blue
Write-Host "==================================================" -ForegroundColor $Blue

function Write-Status {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $Blue
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check if oc is available
    try {
        $null = Get-Command oc -ErrorAction Stop
        $currentUser = & oc whoami 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "OpenShift CLI available and logged in as: $currentUser"
        } else {
            Write-Error "Not logged in to OpenShift cluster"
            return $false
        }
    } catch {
        Write-Error "OpenShift CLI (oc) is not installed or not in PATH"
        return $false
    }
    
    # Check if gh CLI is available
    try {
        $null = Get-Command gh -ErrorAction Stop
        $authStatus = & gh auth status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "GitHub CLI available and authenticated"
        } else {
            Write-Warning "GitHub CLI is not authenticated"
        }
    } catch {
        Write-Warning "GitHub CLI is not installed - manual secret setup required"
    }
    
    # Check if kubectl is available
    try {
        $null = Get-Command kubectl -ErrorAction Stop
        Write-Status "kubectl CLI available"
    } catch {
        Write-Warning "kubectl is not installed - some features may not work"
    }
    
    return $true
}

function Export-CurrentSecrets {
    Write-Info "Extracting current secrets from cluster..."
    
    $SecretsDir = Join-Path $ProjectRoot "extracted-secrets"
    if (-not (Test-Path $SecretsDir)) {
        New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
    }
    
    $SecretsFile = Join-Path $SecretsDir "github-secrets.env"
    
    # Extract Azure AD client secret
    try {
        $azureSecret = & oc get secret openid-client-secret-azuread -n openshift-config -o jsonpath='{.data.clientSecret}' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $decodedSecret = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($azureSecret))
            "AZURE_AD_CLIENT_SECRET=$decodedSecret" | Add-Content -Path $SecretsFile
            Write-Status "Extracted Azure AD client secret"
        }
    } catch {
        Write-Warning "Azure AD client secret not found in cluster"
    }
    
    # Extract OADP backup credentials
    try {
        $cloudCreds = & oc get secret cloud-credentials -n openshift-adp -o jsonpath='{.data.cloud}' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $decodedCreds = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cloudCreds))
            $awsAccessKey = ($decodedCreds -split "`n" | Where-Object { $_ -match "aws_access_key_id" }) -replace "aws_access_key_id=", ""
            $awsSecretKey = ($decodedCreds -split "`n" | Where-Object { $_ -match "aws_secret_access_key" }) -replace "aws_secret_access_key=", ""
            
            "OADP_AWS_ACCESS_KEY_ID=$awsAccessKey" | Add-Content -Path $SecretsFile
            "OADP_AWS_SECRET_ACCESS_KEY=$awsSecretKey" | Add-Content -Path $SecretsFile
            Write-Status "Extracted OADP backup credentials"
        }
    } catch {
        Write-Warning "OADP backup credentials not found in cluster"
    }
    
    # Get cluster information
    $clusterServer = & oc whoami --show-server
    $clusterToken = & oc whoami --show-token
    
    "OPENSHIFT_SERVER=$clusterServer" | Add-Content -Path $SecretsFile
    "OPENSHIFT_TOKEN=$clusterToken" | Add-Content -Path $SecretsFile
    
    Write-Status "Secrets extracted to: $SecretsFile"
    Write-Warning "⚠️  IMPORTANT: This file contains sensitive data - do not commit to Git!"
}

function Install-SealedSecrets {
    Write-Info "Installing Sealed Secrets controller..."
    
    $namespaceExists = & oc get namespace sealed-secrets-system 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Sealed Secrets controller already installed"
        return
    }
    
    # Install Sealed Secrets controller
    & oc apply -f "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml"
    
    # Wait for deployment to be ready
    Write-Info "Waiting for Sealed Secrets controller to be ready..."
    & oc wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets-system
    
    Write-Status "Sealed Secrets controller installed"
}

function Setup-KubesealCert {
    Write-Info "Setting up kubeseal certificate..."
    
    # Wait for the sealed secrets controller to generate the certificate
    Start-Sleep -Seconds 10
    
    # Extract the public certificate
    $SecretsDir = Join-Path $ProjectRoot "extracted-secrets"
    $CertFile = Join-Path $SecretsDir "kubeseal-cert.pem"
    
    $certData = & oc get secret -n sealed-secrets-system sealed-secrets-key -o jsonpath='{.data.tls\.crt}'
    $decodedCert = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($certData))
    $decodedCert | Set-Content -Path $CertFile
    
    # Set as GitHub secret if gh CLI is available
    try {
        $null = Get-Command gh -ErrorAction Stop
        $authStatus = & gh auth status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Get-Content $CertFile | & gh secret set KUBESEAL_CERT --repo $GitHubRepo
            Write-Status "Kubeseal certificate set as GitHub secret"
        } else {
            Write-Warning "Manual setup required for KUBESEAL_CERT GitHub secret"
            Write-Info "Certificate saved to: $CertFile"
        }
    } catch {
        Write-Warning "Manual setup required for KUBESEAL_CERT GitHub secret"
        Write-Info "Certificate saved to: $CertFile"
    }
}

function Setup-GitHubSecrets {
    Write-Info "Setting up GitHub secrets..."
    
    try {
        $null = Get-Command gh -ErrorAction Stop
        $authStatus = & gh auth status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "GitHub CLI is not authenticated. Run: gh auth login"
            return
        }
    } catch {
        Write-Error "GitHub CLI is required for automatic secret setup"
        Write-Info "Please install gh CLI or set up secrets manually"
        return
    }
    
    $SecretsFile = Join-Path $ProjectRoot "extracted-secrets\github-secrets.env"
    
    if (-not (Test-Path $SecretsFile)) {
        Write-Error "Secrets file not found. Run Export-CurrentSecrets first."
        return
    }
    
    Write-Info "Setting GitHub repository secrets..."
    
    # Read secrets from file and set them in GitHub
    Get-Content $SecretsFile | ForEach-Object {
        if ($_ -match '^([A-Z_]+)=(.+)$') {
            $key = $Matches[1]
            $value = $Matches[2]
            Write-Host "Setting secret: $key"
            $value | & gh secret set $key --repo $GitHubRepo
        }
    }
    
    Write-Status "GitHub secrets configured"
}

function Install-Kubeseal {
    Write-Info "Installing kubeseal CLI..."
    
    try {
        $null = Get-Command kubeseal -ErrorAction Stop
        Write-Status "kubeseal already installed"
        return
    } catch {
        # kubeseal not found, install it
    }
    
    $KubesealVersion = "0.24.0"
    $TempDir = [System.IO.Path]::GetTempPath()
    $KubesealDir = Join-Path $TempDir "kubeseal"
    
    if (Test-Path $KubesealDir) {
        Remove-Item $KubesealDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $KubesealDir -Force | Out-Null
    
    $DownloadUrl = "https://github.com/bitnami-labs/sealed-secrets/releases/download/v$KubesealVersion/kubeseal-$KubesealVersion-windows-amd64.tar.gz"
    $TarFile = Join-Path $KubesealDir "kubeseal.tar.gz"
    
    Write-Info "Downloading kubeseal..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TarFile
    
    # Extract tar.gz file (requires tar command available in Windows 10+)
    try {
        & tar -xzf $TarFile -C $KubesealDir
        $KubesealExe = Join-Path $KubesealDir "kubeseal.exe"
        
        # Copy to project directory
        $ProjectKubeseal = Join-Path $ProjectRoot "kubeseal.exe"
        Copy-Item $KubesealExe $ProjectKubeseal
        
        Write-Status "kubeseal installed to project directory"
    } catch {
        Write-Error "Failed to extract kubeseal. Please install manually."
        return
    }
}

function New-SealedSecrets {
    Write-Info "Generating sealed secrets..."
    
    # Ensure kubeseal is available
    $KubesealPath = Join-Path $ProjectRoot "kubeseal.exe"
    if (-not (Test-Path $KubesealPath)) {
        try {
            $null = Get-Command kubeseal -ErrorAction Stop
            $KubesealPath = "kubeseal"
        } catch {
            Install-Kubeseal
            $KubesealPath = Join-Path $ProjectRoot "kubeseal.exe"
        }
    }
    
    $CertFile = Join-Path $ProjectRoot "extracted-secrets\kubeseal-cert.pem"
    $SecretsFile = Join-Path $ProjectRoot "extracted-secrets\github-secrets.env"
    
    if (-not (Test-Path $CertFile)) {
        Write-Error "Kubeseal certificate not found"
        return
    }
    
    if (-not (Test-Path $SecretsFile)) {
        Write-Error "Secrets file not found"
        return
    }
    
    # Generate sealed secret for Azure AD
    $azureSecret = (Get-Content $SecretsFile | Where-Object { $_ -match "AZURE_AD_CLIENT_SECRET" }) -replace "AZURE_AD_CLIENT_SECRET=", ""
    if ($azureSecret) {
        $tempSecret = @"
apiVersion: v1
kind: Secret
metadata:
  name: openid-client-secret-azuread
  namespace: openshift-config
type: Opaque
stringData:
  clientSecret: "$azureSecret"
"@
        $tempSecret | & kubectl create --dry-run=client -f - -o yaml | & $KubesealPath --cert $CertFile -o yaml > "$ProjectRoot\components\oauth-configuration\azure-ad-client-sealed-secret.yaml"
        Write-Status "Generated sealed secret for Azure AD client"
    }
    
    # Generate sealed secret for OADP
    $awsAccessKey = (Get-Content $SecretsFile | Where-Object { $_ -match "OADP_AWS_ACCESS_KEY_ID" }) -replace "OADP_AWS_ACCESS_KEY_ID=", ""
    $awsSecretKey = (Get-Content $SecretsFile | Where-Object { $_ -match "OADP_AWS_SECRET_ACCESS_KEY" }) -replace "OADP_AWS_SECRET_ACCESS_KEY=", ""
    
    if ($awsAccessKey -and $awsSecretKey) {
        $cloudCreds = @"
[default]
aws_access_key_id=$awsAccessKey
aws_secret_access_key=$awsSecretKey
"@
        $tempCredsFile = Join-Path $env:TEMP "cloud-credentials.txt"
        $cloudCreds | Set-Content -Path $tempCredsFile
        
        $tempSecret = @"
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: openshift-adp
type: Opaque
data:
  cloud: $([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cloudCreds)))
"@
        $tempSecret | & kubectl create --dry-run=client -f - -o yaml | & $KubesealPath --cert $CertFile -o yaml > "$ProjectRoot\components\oadp-configuration\backup-storage-sealed-secret.yaml"
        
        Remove-Item $tempCredsFile -Force
        Write-Status "Generated sealed secret for OADP backup credentials"
    }
}

function Test-Setup {
    Write-Info "Validating setup..."
    
    # Check if sealed secrets were generated
    if (Test-Path "$ProjectRoot\components\oauth-configuration\azure-ad-client-sealed-secret.yaml") {
        Write-Status "Azure AD sealed secret generated"
    } else {
        Write-Warning "Azure AD sealed secret not found"
    }
    
    if (Test-Path "$ProjectRoot\components\oadp-configuration\backup-storage-sealed-secret.yaml") {
        Write-Status "OADP sealed secret generated"
    } else {
        Write-Warning "OADP sealed secret not found"
    }
    
    # Check if GitHub workflows exist
    if (Test-Path "$ProjectRoot\.github\workflows\secrets-management.yml") {
        Write-Status "Secrets management workflow configured"
    } else {
        Write-Warning "Secrets management workflow not found"
    }
    
    Write-Status "Setup validation completed"
}

function Show-ManualSetup {
    Write-Host @"

📋 Manual Setup Instructions
================================

1. Set up GitHub Repository Secrets:
   Go to: https://github.com/$GitHubRepo/settings/secrets/actions
   
   Add the following secrets from: $ProjectRoot\extracted-secrets\github-secrets.env
   
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

"@ -ForegroundColor $Blue
}

function Show-Menu {
    Write-Host ""
    Write-Host "Choose an option:" -ForegroundColor $Blue
    Write-Host "1. Full setup (extract secrets + install sealed secrets + setup GitHub)"
    Write-Host "2. Extract current secrets from cluster"
    Write-Host "3. Install Sealed Secrets controller"
    Write-Host "4. Setup GitHub secrets"
    Write-Host "5. Generate sealed secrets"
    Write-Host "6. Validate setup"
    Write-Host "7. Show manual setup instructions"
    Write-Host "8. Exit"
    Write-Host ""
}

# Main execution
function Main {
    if (-not (Test-Prerequisites)) {
        return
    }
    
    do {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-8)"
        
        switch ($choice) {
            "1" {
                Export-CurrentSecrets
                Install-SealedSecrets
                Setup-KubesealCert
                Setup-GitHubSecrets
                New-SealedSecrets
                Test-Setup
            }
            "2" { Export-CurrentSecrets }
            "3" { 
                Install-SealedSecrets
                Setup-KubesealCert
            }
            "4" { Setup-GitHubSecrets }
            "5" { New-SealedSecrets }
            "6" { Test-Setup }
            "7" { Show-ManualSetup }
            "8" { 
                Write-Info "Exiting..."
                break
            }
            default { Write-Error "Invalid choice. Please try again." }
        }
        
        if ($choice -ne "8") {
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
    } while ($choice -ne "8")
}

# Run the main function
Main
