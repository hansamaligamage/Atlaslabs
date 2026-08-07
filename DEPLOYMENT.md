# Azure App Service Deployment Guide

This guide explains how to deploy the Atlaslabs application to Azure App Service using GitHub Actions.

## Prerequisites

- Azure subscription
- Azure CLI installed locally
- GitHub repository for this project
- .NET 10 SDK

## Deployment Options

Two GitHub Actions workflows are provided:

1. **azure-deploy.yml** - Uses publish profile (simpler setup)
2. **azure-deploy-service-principal.yml** - Uses Service Principal (recommended for production)

## Option 1: Deploy Using Publish Profile (Simpler)

### Step 1: Create Azure App Service

```bash
# Login to Azure
az login

# Set variables
RESOURCE_GROUP="atlaslabs-rg"
APP_NAME="atlaslabs-app"
LOCATION="eastus"
PLAN_NAME="atlaslabs-plan"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create App Service Plan (Linux)
az appservice plan create \
  --name $PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku B1 \
  --is-linux

# Create Web App
az webapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --plan $PLAN_NAME \
  --runtime "DOTNET|10.0"
```

### Step 2: Configure App Settings

```bash
# Configure app settings
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    AzureAI__ProjectEndpoint="<your-project-endpoint>" \
    AzureAI__ModelDeploymentName="<your-model-name>" \
    AzureAI__AgentName="<your-agent-name>"

# Enable managed identity
az webapp identity assign \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP
```

### Step 3: Download Publish Profile

```bash
# Download publish profile
az webapp deployment list-publishing-profiles \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --xml > publish-profile.xml
```

### Step 4: Add GitHub Secret

1. Go to your GitHub repository
2. Navigate to **Settings** ? **Secrets and variables** ? **Actions**
3. Click **New repository secret**
4. Name: `AZURE_WEBAPP_PUBLISH_PROFILE`
5. Value: Paste the contents of `publish-profile.xml`
6. Click **Add secret**

### Step 5: Update Workflow File

Edit `.github/workflows/azure-deploy.yml` and update:
- `AZURE_WEBAPP_NAME` to your app name

### Step 6: Push to GitHub

```bash
git add .
git commit -m "Add Azure deployment workflow"
git push origin main
```

## Option 2: Deploy Using Service Principal (Recommended)

### Step 1: Create Azure Resources

```bash
# Login to Azure
az login

# Set variables
RESOURCE_GROUP="atlaslabs-rg"
APP_NAME="atlaslabs-app"
LOCATION="eastus"
PLAN_NAME="atlaslabs-plan"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create App Service Plan
az appservice plan create \
  --name $PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku B1 \
  --is-linux

# Create Web App
az webapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --plan $PLAN_NAME \
  --runtime "DOTNET|10.0"
```

### Step 2: Create Service Principal

```bash
# Create service principal and assign contributor role
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "atlaslabs-github-deploy" \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
  --sdk-auth)

echo $SP_OUTPUT
```

### Step 3: Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** ? **Secrets and variables** ? **Actions**
3. Add the following secret:
   - Name: `AZURE_CREDENTIALS`
   - Value: The entire JSON output from the service principal creation

### Step 4: Configure App Settings

```bash
# Configure app settings
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    AzureAI__ProjectEndpoint="<your-project-endpoint>" \
    AzureAI__ModelDeploymentName="<your-model-name>" \
    AzureAI__AgentName="<your-agent-name>" \
    ASPNETCORE_ENVIRONMENT="Production"

# Enable managed identity
az webapp identity assign \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP

# Get the principal ID
PRINCIPAL_ID=$(az webapp identity show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

# Grant the managed identity access to Azure AI (if needed)
# Replace <AI_RESOURCE_ID> with your Azure AI resource ID
# az role assignment create \
#   --assignee $PRINCIPAL_ID \
#   --role "Cognitive Services User" \
#   --scope <AI_RESOURCE_ID>
```

### Step 5: Update Workflow File

Edit `.github/workflows/azure-deploy-service-principal.yml` and update:
- `AZURE_WEBAPP_NAME` to your app name
- `RESOURCE_GROUP` to your resource group name
- `AZURE_REGION` to your preferred region

### Step 6: Create Production Environment (Optional)

1. Go to your GitHub repository
2. Navigate to **Settings** ? **Environments**
3. Click **New environment**
4. Name it `Production`
5. Add protection rules if desired (e.g., required reviewers)

### Step 7: Push to GitHub

```bash
git add .
git commit -m "Add Azure deployment with Service Principal"
git push origin main
```

## Workflow Features

Both workflows include:
- ? Automatic build on push to main branch
- ? Manual trigger via workflow_dispatch
- ? Dependency restore and build
- ? Application publishing
- ? Deployment to Azure App Service

The Service Principal workflow additionally includes:
- ? Separate build and deploy jobs
- ? Artifact upload/download between jobs
- ? Test execution (if tests exist)
- ? Environment URLs
- ? Azure logout on completion

## Verify Deployment

After deployment completes:

```bash
# Get the app URL
az webapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query defaultHostName -o tsv

# Browse to the URL
# https://<your-app-name>.azurewebsites.net
```

## Monitoring

View deployment logs:
- GitHub Actions: Go to **Actions** tab in your repository
- Azure Portal: Navigate to your App Service ? **Deployment Center** ? **Logs**

View application logs:

```bash
# Stream logs
az webapp log tail \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP
```

## Troubleshooting

### Common Issues

1. **Build Fails**: Check .NET version matches in workflow and project
2. **Deployment Fails**: Verify app name and credentials
3. **App Doesn't Start**: Check application settings and logs
4. **Authentication Issues**: Ensure managed identity has proper permissions

### Enable Application Insights

```bash
# Create Application Insights
az monitor app-insights component create \
  --app atlaslabs-insights \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP

# Get instrumentation key
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app atlaslabs-insights \
  --resource-group $RESOURCE_GROUP \
  --query instrumentationKey -o tsv)

# Add to app settings
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY=$INSTRUMENTATION_KEY
```

## Clean Up Resources

To delete all resources:

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Security Best Practices

1. **Use Managed Identity**: Enable managed identity for Azure service authentication
2. **Secrets Management**: Store sensitive data in Azure Key Vault
3. **HTTPS Only**: Enable HTTPS-only traffic
4. **Environment Variables**: Use app settings for configuration
5. **Least Privilege**: Grant minimal permissions to service principals

## Additional Configuration

### Enable HTTPS Only

```bash
az webapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --https-only true
```

### Configure Custom Domain

```bash
# Add custom domain
az webapp config hostname add \
  --webapp-name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --hostname www.yourdomain.com
```

### Scale Up/Out

```bash
# Scale up (change SKU)
az appservice plan update \
  --name $PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --sku S1

# Scale out (add instances)
az appservice plan update \
  --name $PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --number-of-workers 3
```

## Support

For issues or questions:
- Check GitHub Actions logs
- Review Azure App Service logs
- Check Azure AI Project configuration
- Verify all secrets and app settings are correct
