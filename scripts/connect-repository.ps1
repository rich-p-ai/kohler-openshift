# PowerShell script to connect Kohler OpenShift repository to the cluster
# This script sets up the ArgoCD applications to manage the kohler-openshift repository

param(
    [string]$GitopsRepo = "https://github.com/kohler-openshift/kohler-openshift.git",
    [string]$ClusterName = "hub",
    [string]$Namespace = "openshift-gitops"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Connecting Kohler OpenShift repository to cluster..." -ForegroundColor Green

# Check if we're logged into the cluster
try {
    $null = & oc whoami 2>$null
} catch {
    Write-Host "❌ Error: You must be logged into an OpenShift cluster" -ForegroundColor Red
    exit 1
}

# Check if ArgoCD is installed
try {
    $null = & oc get ns openshift-gitops 2>$null
} catch {
    Write-Host "❌ Error: openshift-gitops namespace not found. Please install OpenShift GitOps operator first." -ForegroundColor Red
    exit 1
}

# Get cluster information
$ClusterBaseDomain = (& oc get ingress.config.openshift.io cluster --template="{{.spec.domain}}") -replace "^apps\.", ""
$PlatformBaseDomain = $ClusterBaseDomain -replace "^[^.]+\.", ""

Write-Host "📋 Configuration:" -ForegroundColor Cyan
Write-Host "   GitOps Repository: $GitopsRepo" -ForegroundColor White
Write-Host "   Cluster Name: $ClusterName" -ForegroundColor White
Write-Host "   Cluster Base Domain: $ClusterBaseDomain" -ForegroundColor White
Write-Host "   Platform Base Domain: $PlatformBaseDomain" -ForegroundColor White

# Set environment variables for substitution
$env:gitops_repo = $GitopsRepo
$env:cluster_name = $ClusterName
$env:cluster_base_domain = $ClusterBaseDomain
$env:platform_base_domain = $PlatformBaseDomain

Write-Host "📦 Applying bootstrap configurations..." -ForegroundColor Yellow

try {
    # Apply bootstrap configurations in order
    Write-Host "   → Applying namespace configuration..." -ForegroundColor Gray
    & oc apply -f .bootstrap/0.namespace.yaml

    Write-Host "   → Applying subscription..." -ForegroundColor Gray
    & oc apply -f .bootstrap/subscription.yaml

    Write-Host "   → Applying operator group..." -ForegroundColor Gray
    & oc apply -f .bootstrap/2.operatorgroup.yaml

    Write-Host "   → Applying cluster role binding..." -ForegroundColor Gray
    & oc apply -f .bootstrap/2.cluster-rolebinding.yaml

    Write-Host "   → Waiting for OpenShift GitOps to be ready..." -ForegroundColor Gray
    Start-Sleep -Seconds 60

    Write-Host "   → Applying ArgoCD configuration..." -ForegroundColor Gray
    $argoCdContent = Get-Content .bootstrap/argocd.yaml -Raw
    $argoCdContent = $argoCdContent -replace '\${gitops_repo}', $env:gitops_repo
    $argoCdContent = $argoCdContent -replace '\${cluster_name}', $env:cluster_name
    $argoCdContent = $argoCdContent -replace '\${cluster_base_domain}', $env:cluster_base_domain
    $argoCdContent = $argoCdContent -replace '\${platform_base_domain}', $env:platform_base_domain
    $argoCdContent | & oc apply -f -

    Write-Host "   → Waiting for ArgoCD to be ready..." -ForegroundColor Gray
    Start-Sleep -Seconds 30

    Write-Host "   → Applying root application..." -ForegroundColor Gray
    $rootAppContent = Get-Content .bootstrap/3.root-application.yaml -Raw
    $rootAppContent = $rootAppContent -replace '\${gitops_repo}', $env:gitops_repo
    $rootAppContent = $rootAppContent -replace '\${cluster_name}', $env:cluster_name
    $rootAppContent = $rootAppContent -replace '\${cluster_base_domain}', $env:cluster_base_domain
    $rootAppContent = $rootAppContent -replace '\${platform_base_domain}', $env:platform_base_domain
    $rootAppContent | & oc apply -f -

    Write-Host "   → Applying Kohler OpenShift connection..." -ForegroundColor Gray
    & oc apply -f .bootstrap/4.kohler-openshift-connection.yaml

    Write-Host "✅ Kohler OpenShift repository successfully connected to cluster!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔍 You can monitor the deployment status with:" -ForegroundColor Cyan
    Write-Host "   oc get applications -n openshift-gitops" -ForegroundColor White
    Write-Host ""
    Write-Host "🌐 Access ArgoCD UI at:" -ForegroundColor Cyan
    Write-Host "   https://openshift-gitops-server-openshift-gitops.apps.$ClusterBaseDomain" -ForegroundColor White
    Write-Host ""
    Write-Host "🔑 Get ArgoCD admin password with:" -ForegroundColor Cyan
    Write-Host "   oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=- --keys=admin.password" -ForegroundColor White

} catch {
    Write-Host "❌ Error during deployment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
