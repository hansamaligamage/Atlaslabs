# Azure App Service Setup Script (PowerShell)
# This script automates the creation of Azure resources for the Atlaslabs application

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure App Service Setup for Atlaslabs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure CLI is installed
try {
    az --version | Out-Null
} catch {
    Write-Host "Error: Azure CLI is not installed. Please install it first." -ForegroundColor Red
    Write-Host "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Prompt for variables
$RESOURCE_GROUP = Read-Host "Enter Resource Group name [atlaslabs-rg]"
if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) { $RESOURCE_GROUP = "atlaslabs-rg" }

$APP_NAME = Read-Host "Enter App Service name [atlaslabs-app]"
if ([string]::IsNullOrWhiteSpace($APP_NAME)) { $APP_NAME = "atlaslabs-app" }

$LOCATION = Read-Host "Enter Azure region [eastus]"
if ([string]::IsNullOrWhiteSpace($LOCATION)) { $LOCATION = "eastus" }

$PLAN_NAME = Read-Host "Enter App Service Plan name [atlaslabs-plan]"
if ([string]::IsNullOrWhiteSpace($PLAN_NAME)) { $PLAN_NAME = "atlaslabs-plan" }

$SKU = Read-Host "Enter SKU (F1=Free, B1=Basic, S1=Standard) [B1]"
if ([string]::IsNullOrWhiteSpace($SKU)) { $SKU = "B1" }

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $RESOURCE_GROUP"
Write-Host "  App Name: $APP_NAME"
Write-Host "  Location: $LOCATION"
Write-Host "  Plan Name: $PLAN_NAME"
Write-Host "  SKU: $SKU"
Write-Host ""

$CONFIRM = Read-Host "Do you want to continue? (yes/no)"
if ($CONFIRM -ne "yes") {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Step 1: Logging in to Azure..." -ForegroundColor Green
az login

# Get subscription ID
$SUBSCRIPTION_ID = az account show --query id -o tsv
Write-Host "Using subscription: $SUBSCRIPTION_ID" -ForegroundColor Cyan

Write-Host ""
Write-Host "Step 2: Creating resource group..." -ForegroundColor Green
$groupExists = az group exists --name $RESOURCE_GROUP
if ($groupExists -eq "true") {
    Write-Host "Resource group already exists. Skipping..." -ForegroundColor Yellow
} else {
    az group create --name $RESOURCE_GROUP --location $LOCATION
    Write-Host "Resource group created successfully." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Step 3: Creating App Service Plan..." -ForegroundColor Green
try {
    az appservice plan show --name $PLAN_NAME --resource-group $RESOURCE_GROUP 2>$null | Out-Null
    Write-Host "App Service Plan already exists. Skipping..." -ForegroundColor Yellow
} catch {
    az appservice plan create `
      --name $PLAN_NAME `
      --resource-group $RESOURCE_GROUP `
      --location $LOCATION `
      --sku $SKU `
      --is-linux
    Write-Host "App Service Plan created successfully." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Step 4: Creating Web App..." -ForegroundColor Green
try {
    az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP 2>$null | Out-Null
    Write-Host "Web App already exists. Skipping..." -ForegroundColor Yellow
} catch {
    az webapp create `
      --name $APP_NAME `
      --resource-group $RESOURCE_GROUP `
      --plan $PLAN_NAME `
      --runtime "DOTNET:10.0"
    Write-Host "Web App created successfully." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Step 5: Enabling managed identity..." -ForegroundColor Green
az webapp identity assign `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP
Write-Host "Managed identity enabled." -ForegroundColor Cyan

Write-Host ""
Write-Host "Step 6: Configuring app settings..." -ForegroundColor Green
$AI_ENDPOINT = Read-Host "Enter Azure AI Project Endpoint (or press Enter to skip)"
$MODEL_NAME = Read-Host "Enter Model Deployment Name (or press Enter to skip)"
$AGENT_NAME = Read-Host "Enter Agent Name (or press Enter to skip)"

if (![string]::IsNullOrWhiteSpace($AI_ENDPOINT) -and 
    ![string]::IsNullOrWhiteSpace($MODEL_NAME) -and 
    ![string]::IsNullOrWhiteSpace($AGENT_NAME)) {
    
    az webapp config appsettings set `
      --name $APP_NAME `
      --resource-group $RESOURCE_GROUP `
      --settings `
        "AzureAI__ProjectEndpoint=$AI_ENDPOINT" `
        "AzureAI__ModelDeploymentName=$MODEL_NAME" `
        "AzureAI__AgentName=$AGENT_NAME" `
        "ASPNETCORE_ENVIRONMENT=Production"
    Write-Host "App settings configured." -ForegroundColor Cyan
} else {
    Write-Host "Skipping app settings configuration. You can set them later in Azure Portal." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 7: Enabling HTTPS only..." -ForegroundColor Green
az webapp update `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --https-only true
Write-Host "HTTPS-only enabled." -ForegroundColor Cyan

Write-Host ""
$CREATE_SP = Read-Host "Do you want to create a Service Principal for GitHub Actions? (yes/no)"
if ($CREATE_SP -eq "yes") {
    Write-Host ""
    Write-Host "Step 8: Creating Service Principal..." -ForegroundColor Green
    $SP_NAME = "$APP_NAME-github-deploy"
    
    $SP_OUTPUT = az ad sp create-for-rbac `
      --name $SP_NAME `
      --role contributor `
      --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" `
      --sdk-auth
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "GitHub Actions Configuration" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Add the following as a GitHub secret named 'AZURE_CREDENTIALS':" -ForegroundColor Yellow
    Write-Host ""
    Write-Host $SP_OUTPUT -ForegroundColor White
    Write-Host ""
    Write-Host "To add this secret:" -ForegroundColor Yellow
    Write-Host "1. Go to your GitHub repository"
    Write-Host "2. Navigate to Settings ? Secrets and variables ? Actions"
    Write-Host "3. Click 'New repository secret'"
    Write-Host "4. Name: AZURE_CREDENTIALS"
    Write-Host "5. Value: (paste the JSON above)"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Step 8: Downloading publish profile..." -ForegroundColor Green
    az webapp deployment list-publishing-profiles `
      --name $APP_NAME `
      --resource-group $RESOURCE_GROUP `
      --xml | Out-File -FilePath "publish-profile.xml" -Encoding utf8
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "GitHub Actions Configuration" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Publish profile saved to: publish-profile.xml" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Add this as a GitHub secret named 'AZURE_WEBAPP_PUBLISH_PROFILE':" -ForegroundColor Yellow
    Write-Host "1. Go to your GitHub repository"
    Write-Host "2. Navigate to Settings ? Secrets and variables ? Actions"
    Write-Host "3. Click 'New repository secret'"
    Write-Host "4. Name: AZURE_WEBAPP_PUBLISH_PROFILE"
    Write-Host "5. Value: (paste the contents of publish-profile.xml)"
    Write-Host ""
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your application URL: https://$APP_NAME.azurewebsites.net" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure GitHub secrets (see above)"
Write-Host "2. Update workflow file with your app name"
Write-Host "3. Push your code to trigger deployment"
Write-Host ""
Write-Host "View your resources:" -ForegroundColor Yellow
Write-Host "  az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP"
Write-Host ""
Write-Host "Stream logs:" -ForegroundColor Yellow
Write-Host "  az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP"
Write-Host ""
