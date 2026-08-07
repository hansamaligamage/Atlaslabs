#!/bin/bash

# Azure App Service Setup Script
# This script automates the creation of Azure resources for the Atlaslabs application

set -e

echo "========================================"
echo "Azure App Service Setup for Atlaslabs"
echo "========================================"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Prompt for variables
read -p "Enter Resource Group name [atlaslabs-rg]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-atlaslabs-rg}

read -p "Enter App Service name [atlaslabs-app]: " APP_NAME
APP_NAME=${APP_NAME:-atlaslabs-app}

read -p "Enter Azure region [eastus]: " LOCATION
LOCATION=${LOCATION:-eastus}

read -p "Enter App Service Plan name [atlaslabs-plan]: " PLAN_NAME
PLAN_NAME=${PLAN_NAME:-atlaslabs-plan}

read -p "Enter SKU (F1=Free, B1=Basic, S1=Standard) [B1]: " SKU
SKU=${SKU:-B1}

echo ""
echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  App Name: $APP_NAME"
echo "  Location: $LOCATION"
echo "  Plan Name: $PLAN_NAME"
echo "  SKU: $SKU"
echo ""

read -p "Do you want to continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "Step 1: Logging in to Azure..."
az login

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Using subscription: $SUBSCRIPTION_ID"

echo ""
echo "Step 2: Creating resource group..."
if az group exists --name $RESOURCE_GROUP | grep -q true; then
    echo "Resource group already exists. Skipping..."
else
    az group create --name $RESOURCE_GROUP --location $LOCATION
    echo "Resource group created successfully."
fi

echo ""
echo "Step 3: Creating App Service Plan..."
if az appservice plan show --name $PLAN_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "App Service Plan already exists. Skipping..."
else
    az appservice plan create \
      --name $PLAN_NAME \
      --resource-group $RESOURCE_GROUP \
      --location $LOCATION \
      --sku $SKU \
      --is-linux
    echo "App Service Plan created successfully."
fi

echo ""
echo "Step 4: Creating Web App..."
if az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "Web App already exists. Skipping..."
else
    az webapp create \
      --name $APP_NAME \
      --resource-group $RESOURCE_GROUP \
      --plan $PLAN_NAME \
      --runtime "DOTNET|10.0"
    echo "Web App created successfully."
fi

echo ""
echo "Step 5: Enabling managed identity..."
az webapp identity assign \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP
echo "Managed identity enabled."

echo ""
echo "Step 6: Configuring app settings..."
read -p "Enter Azure AI Project Endpoint (or press Enter to skip): " AI_ENDPOINT
read -p "Enter Model Deployment Name (or press Enter to skip): " MODEL_NAME
read -p "Enter Agent Name (or press Enter to skip): " AGENT_NAME

if [ ! -z "$AI_ENDPOINT" ] && [ ! -z "$MODEL_NAME" ] && [ ! -z "$AGENT_NAME" ]; then
    az webapp config appsettings set \
      --name $APP_NAME \
      --resource-group $RESOURCE_GROUP \
      --settings \
        AzureAI__ProjectEndpoint="$AI_ENDPOINT" \
        AzureAI__ModelDeploymentName="$MODEL_NAME" \
        AzureAI__AgentName="$AGENT_NAME" \
        ASPNETCORE_ENVIRONMENT="Production"
    echo "App settings configured."
else
    echo "Skipping app settings configuration. You can set them later in Azure Portal."
fi

echo ""
echo "Step 7: Enabling HTTPS only..."
az webapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --https-only true
echo "HTTPS-only enabled."

echo ""
read -p "Do you want to create a Service Principal for GitHub Actions? (yes/no): " CREATE_SP
if [ "$CREATE_SP" = "yes" ]; then
    echo ""
    echo "Step 8: Creating Service Principal..."
    SP_NAME="$APP_NAME-github-deploy"
    
    SP_OUTPUT=$(az ad sp create-for-rbac \
      --name "$SP_NAME" \
      --role contributor \
      --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
      --sdk-auth)
    
    echo ""
    echo "========================================"
    echo "GitHub Actions Configuration"
    echo "========================================"
    echo ""
    echo "Add the following as a GitHub secret named 'AZURE_CREDENTIALS':"
    echo ""
    echo "$SP_OUTPUT"
    echo ""
    echo "To add this secret:"
    echo "1. Go to your GitHub repository"
    echo "2. Navigate to Settings ? Secrets and variables ? Actions"
    echo "3. Click 'New repository secret'"
    echo "4. Name: AZURE_CREDENTIALS"
    echo "5. Value: (paste the JSON above)"
    echo ""
else
    echo ""
    echo "Step 8: Downloading publish profile..."
    az webapp deployment list-publishing-profiles \
      --name $APP_NAME \
      --resource-group $RESOURCE_GROUP \
      --xml > publish-profile.xml
    
    echo ""
    echo "========================================"
    echo "GitHub Actions Configuration"
    echo "========================================"
    echo ""
    echo "Publish profile saved to: publish-profile.xml"
    echo ""
    echo "Add this as a GitHub secret named 'AZURE_WEBAPP_PUBLISH_PROFILE':"
    echo "1. Go to your GitHub repository"
    echo "2. Navigate to Settings ? Secrets and variables ? Actions"
    echo "3. Click 'New repository secret'"
    echo "4. Name: AZURE_WEBAPP_PUBLISH_PROFILE"
    echo "5. Value: (paste the contents of publish-profile.xml)"
    echo ""
fi

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Your application URL: https://$APP_NAME.azurewebsites.net"
echo ""
echo "Next steps:"
echo "1. Configure GitHub secrets (see above)"
echo "2. Update workflow file with your app name"
echo "3. Push your code to trigger deployment"
echo ""
echo "View your resources:"
echo "  az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo ""
echo "Stream logs:"
echo "  az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo ""
