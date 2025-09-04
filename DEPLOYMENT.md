# Multi-Environment Deployment Guide

## Overview

The API Translator Logic App infrastructure is fully parameterized to support deployment across multiple environments (dev, test, staging, production) using different resource names and configurations.

## Infrastructure Parameters

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `environmentName` | Environment suffix for resources | `dev`, `test`, `prod` |
| `location` | Azure region for deployment | `eastus`, `westus2` |
| `integrationAccountId` | Full resource ID of Integration Account | `/subscriptions/.../az-d-ia-b2bIntegration` |
| `existingKeyVaultName` | Name of existing Key Vault | `az-d-kv-b2bInt-eus-01` |
| `existingManagedIdentityName` | Name of existing managed identity | `az-d-mi-ApiTranslator-eus-01` |
| `existingResourceGroupName` | Resource group with Key Vault and identity | `az-d-rg-b2bIntegration` |
| `appServicePlanName` | Name for the App Service Plan | `az-d-asp-ApiTranslator-eus-03` |
| `logicAppName` | Name for the Logic App | `az-d-lap-ApiTranslator-eus-03` |

### Optional Parameters with Defaults

| Parameter | Default | Description | Options |
|-----------|---------|-------------|---------|
| `resourcePrefix` | `atr` | Prefix for auto-generated resource names | Max 3 characters |
| `appServicePlanSku` | `WS1` | App Service Plan SKU | `WS1`, `WS2`, `WS3` |
| `appServicePlanTier` | `WorkflowStandard` | App Service Plan tier | `WorkflowStandard` |
| `maxElasticWorkerCount` | `20` | Maximum workers for scaling | Integer |
| `targetWorkerCount` | `1` | Target number of workers | Integer |
| `logAnalyticsRetentionDays` | `30` | Log retention period | 30-730 days |
| `storageAccountType` | `Standard_LRS` | Storage redundancy | `Standard_LRS`, `Standard_GRS`, etc. |
| `storageAccountTier` | `Hot` | Storage access tier | `Hot`, `Cool` |

## Environment-Specific Configurations

### Development Environment (`main.parameters.dev.json`)
- **Purpose**: Development and testing
- **Cost Optimized**: Lower SKUs and reduced redundancy
- **Configuration**:
  - App Service Plan: WS1 (Basic)
  - Max Workers: 10
  - Storage: Standard_LRS
  - Log Retention: 30 days

### Production Environment (`main.parameters.prod.json`)
- **Purpose**: Production workloads
- **High Availability**: Higher SKUs and geo-redundancy
- **Configuration**:
  - App Service Plan: WS2 (Enhanced)
  - Max Workers: 50
  - Target Workers: 3
  - Storage: Standard_GRS (Geo-redundant)
  - Log Retention: 90 days

## Deployment Commands

### Using Azure Developer CLI (Recommended)

```bash
# Deploy to development environment
azd up --environment dev

# Deploy to production environment  
azd up --environment prod
```

### Using Azure CLI with Specific Parameter Files

```bash
# Deploy to development
az deployment group create \
  --resource-group az-d-rg-ApiTranslator \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.dev.json

# Deploy to production
az deployment group create \
  --resource-group az-p-rg-ApiTranslator \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.prod.json
```

### Using Azure CLI with Parameter Overrides

```bash
# Override specific parameters for a custom deployment
az deployment group create \
  --resource-group my-custom-rg \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json \
  --parameters environmentName=staging \
              appServicePlanSku=WS2 \
              maxElasticWorkerCount=30
```

## Environment Setup Checklist

Before deploying to a new environment, ensure:

### Prerequisites
- [ ] Azure subscription access
- [ ] Resource group created (target for Logic App resources)
- [ ] Integration Account exists (for B2B operations)
- [ ] Key Vault exists with appropriate access policies
- [ ] User-assigned managed identity exists
- [ ] Managed identity has Key Vault Secrets Officer role on Key Vault

### Resource Naming Convention
Follow the established naming pattern:
- **Development**: `az-d-{service}-{appname}-{region}-{instance}`
- **Production**: `az-p-{service}-{appname}-{region}-{instance}`
- **Testing**: `az-t-{service}-{appname}-{region}-{instance}`

Example:
- Dev Logic App: `az-d-lap-ApiTranslator-eus-03`
- Prod Logic App: `az-p-lap-ApiTranslator-eus-03`

## Parameter File Customization

### Creating a New Environment

1. Copy an existing parameter file:
   ```bash
   cp infra/main.parameters.dev.json infra/main.parameters.staging.json
   ```

2. Update environment-specific values:
   - Change `environmentName` to match your environment
   - Update resource names to follow naming convention
   - Adjust SKUs and scaling parameters based on requirements
   - Update Integration Account, Key Vault, and Managed Identity references

3. Test the deployment:
   ```bash
   az deployment group validate \
     --resource-group your-target-rg \
     --template-file infra/main.bicep \
     --parameters @infra/main.parameters.staging.json
   ```

## Security Considerations

### Cross-Environment Isolation
- Use separate Key Vaults for different environments
- Use separate managed identities per environment
- Implement separate Integration Accounts for prod vs non-prod

### Secrets Management
- Store connection strings in Key Vault
- Use Key Vault references in app settings
- Rotate secrets regularly using automated processes

### RBAC Best Practices
- Grant minimum required permissions
- Use environment-specific service principals for CI/CD
- Regular access reviews and cleanup

## Monitoring and Observability

Each environment includes:
- **Application Insights** for application telemetry
- **Log Analytics Workspace** for centralized logging
- **Diagnostic Settings** for Logic App monitoring
- **Custom dashboards** for environment-specific metrics

## Cost Optimization

### Development/Test Environments
- Use Basic SKUs (WS1)
- Lower worker counts
- Shorter log retention periods
- Standard_LRS storage

### Production Environments
- Use appropriate SKUs for workload (WS2/WS3)
- Higher worker counts for availability
- Extended log retention for compliance
- Geo-redundant storage for disaster recovery

## Troubleshooting

### Common Issues
1. **Role Assignment Failures**: Ensure managed identity exists before deployment
2. **Cross-Resource Group References**: Verify existing resource names and resource group names
3. **Naming Conflicts**: Check for existing resources with same names
4. **Permission Issues**: Verify deployment principal has Contributor access

### Validation Commands
```bash
# Check resource group exists
az group show --name az-d-rg-b2bIntegration

# Verify managed identity
az identity show --name az-d-mi-ApiTranslator-eus-01 --resource-group az-d-rg-b2bIntegration

# Validate Key Vault access
az keyvault show --name az-d-kv-b2bInt-eus-01 --resource-group az-d-rg-b2bIntegration
```
