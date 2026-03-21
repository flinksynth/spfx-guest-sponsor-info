targetScope = 'resourceGroup'

metadata name = 'Guest Sponsor Info – Azure Function Proxy'
metadata description = 'Deploys an Azure Function App that acts as a Graph API proxy for the Guest Sponsor Info SharePoint web part. Includes a Storage Account, App Service Plan, EasyAuth configuration, Managed Identity role assignments, Log Analytics Workspace, and Application Insights.'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Entra tenant ID (GUID).')
param tenantId string

@description('Tenant name without domain suffix, e.g. "contoso".')
param tenantName string

@description('Globally unique name for the Function App (2–58 characters, letters, numbers, and hyphens only).')
@minLength(2)
@maxLength(58)
param functionAppName string

@description('Client ID of the App Registration created for EasyAuth.')
param functionClientId string

@description('URL to the pre-built function ZIP package (GitHub Release asset).')
param packageUrl string = 'https://github.com/jpawlowski/spfx-guest-sponsor-info/releases/latest/download/guest-sponsor-info-function.zip'

@description('Resource tags to apply to all deployed resources.')
param tags object = {}

@description('Deploy Azure Maps account for inline address map preview.')
param deployAzureMaps bool = true

@description('Optional custom Azure Maps account name. Leave empty to auto-generate.')
param azureMapsAccountName string = ''

@description('Enable operational email alert for probable service outage (5xx/504 spike or low success rate).')
param enableServiceOutageAlert bool = true

@description('Enable operational email alert for auth/config regressions (AUTH_CONFIG_* reason codes).')
param enableAuthConfigRegressionAlert bool = true

@description('Enable info-only alert for likely attack/noise spikes (high 401/403 from many IPs).')
param enableLikelyAttackInfoAlert bool = true

@description('KQL alert evaluation frequency in minutes.')
@minValue(1)
param alertEvaluationFrequencyInMinutes int = 5

@description('KQL alert lookback window in minutes.')
@minValue(5)
param alertWindowInMinutes int = 15

@description('Minimum total requests in window before service outage alert can fire.')
@minValue(1)
param serviceOutageMinRequests int = 20

@description('5xx/504 count threshold for service outage alert.')
@minValue(1)
param serviceOutageFailureCountThreshold int = 10

@description('Success-rate percentage threshold below which service outage alert can fire.')
@minValue(1)
@maxValue(99)
param serviceOutageSuccessRatePercentThreshold int = 70

@description('AUTH_CONFIG_* trace count threshold for config-regression alert.')
@minValue(1)
param authConfigRegressionHitsThreshold int = 1

@description('401/403 count threshold for likely-attack info alert.')
@minValue(1)
param likelyAttackDeniedCountThreshold int = 50

@description('Unique client IP threshold for likely-attack info alert.')
@minValue(1)
param likelyAttackUniqueIpThreshold int = 20

@description('Denied-rate percentage threshold for likely-attack info alert.')
@minValue(1)
@maxValue(100)
param likelyAttackDenyRatePercentThreshold int = 80

@description('Minimum successful requests required before likely-attack info alert fires (avoid pure outage overlap).')
@minValue(0)
param likelyAttackMinSuccessThreshold int = 1

@description('Action group resource IDs for operational email alerts. Leave empty to create alert rules without notifications.')
param operationalActionGroupResourceIds array = []

@description('Action group resource IDs for info-only alerts. Leave empty to create alert rules without notifications.')
param infoActionGroupResourceIds array = []

@description('Optional notification email used to auto-create default operational/info action groups. Leave empty to skip auto-creation.')
param defaultAlertNotificationEmail string = ''

@description('Short name for the auto-created operational action group (max 12 chars).')
@maxLength(12)
param defaultOperationalActionGroupShortName string = 'GSIOps'

@description('Short name for the auto-created info action group (max 12 chars).')
@maxLength(12)
param defaultInfoActionGroupShortName string = 'GSIInfo'

var storageAccountName = toLower(replace(functionAppName, '-', ''))
var appServicePlanName = '${functionAppName}-plan'
var logAnalyticsWorkspaceName = '${functionAppName}-logs'
var appInsightsName = '${functionAppName}-insights'
var azureMapsName = empty(azureMapsAccountName)
  ? toLower('maps${uniqueString(resourceGroup().id, functionAppName)}')
  : toLower(azureMapsAccountName)
// KQL queries use triple-quoted raw strings (no interpolation) with replace() for parameters.
var serviceOutageAlertQueryRaw = '''
let window = __WINDOW__m;
let req = requests
| where timestamp > ago(window)
| where name contains "getGuestSponsors";
let total = toscalar(req | count);
let failures5xx = toscalar(req | where resultCode startswith "5" or resultCode == "504" | count);
let success = toscalar(req | where resultCode startswith "2" | count);
print total=total, failures5xx=failures5xx, success=success,
      successRatePct = iff(total == 0, 100.0, todouble(success) * 100.0 / todouble(total))
| where total >= __MIN_REQUESTS__
| where failures5xx >= __FAILURE_COUNT__ or successRatePct < __SUCCESS_RATE_PCT__
'''
#disable-next-line prefer-interpolation
var serviceOutageAlertQuery = replace(replace(replace(replace(serviceOutageAlertQueryRaw, '__WINDOW__', string(alertWindowInMinutes)), '__MIN_REQUESTS__', string(serviceOutageMinRequests)), '__FAILURE_COUNT__', string(serviceOutageFailureCountThreshold)), '__SUCCESS_RATE_PCT__', string(serviceOutageSuccessRatePercentThreshold))

var authConfigRegressionAlertQueryRaw = '''
let window = __WINDOW__m;
traces
| where timestamp > ago(window)
| where message has "Client validation ("
| extend reasonCode = tostring(customDimensions.reasonCode)
| where reasonCode in ("AUTH_CONFIG_TENANT_MISSING", "AUTH_CONFIG_AUDIENCE_MISSING")
| summarize hits = count() by reasonCode
| where hits >= __HITS_THRESHOLD__
'''
#disable-next-line prefer-interpolation
var authConfigRegressionAlertQuery = replace(replace(authConfigRegressionAlertQueryRaw, '__WINDOW__', string(alertWindowInMinutes)), '__HITS_THRESHOLD__', string(authConfigRegressionHitsThreshold))

var likelyAttackInfoAlertQueryRaw = '''
let window = __WINDOW__m;
let req = requests
| where timestamp > ago(window)
| where name contains "getGuestSponsors";
let denied = req
| where resultCode in ("401", "403")
| summarize deniedCount = count(), uniqueIps = dcount(client_IP);
let total = toscalar(req | count);
let success = toscalar(req | where resultCode startswith "2" | count);
denied
| extend denyRatePct = iff(total == 0, 0.0, todouble(deniedCount) * 100.0 / todouble(total))
| where deniedCount >= __DENIED_COUNT__
| where uniqueIps >= __UNIQUE_IP__
| where denyRatePct >= __DENY_RATE_PCT__
| where success >= __MIN_SUCCESS__
'''
#disable-next-line prefer-interpolation
var likelyAttackInfoAlertQuery = replace(replace(replace(replace(replace(likelyAttackInfoAlertQueryRaw, '__WINDOW__', string(alertWindowInMinutes)), '__DENIED_COUNT__', string(likelyAttackDeniedCountThreshold)), '__UNIQUE_IP__', string(likelyAttackUniqueIpThreshold)), '__DENY_RATE_PCT__', string(likelyAttackDenyRatePercentThreshold)), '__MIN_SUCCESS__', string(likelyAttackMinSuccessThreshold))
var createDefaultActionGroups = !empty(defaultAlertNotificationEmail)

resource defaultOperationalActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (createDefaultActionGroups) {
  name: '${functionAppName}-ops-ag'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: defaultOperationalActionGroupShortName
    enabled: true
    emailReceivers: [
      {
        name: 'ops-email'
        emailAddress: defaultAlertNotificationEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource defaultInfoActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (createDefaultActionGroups) {
  name: '${functionAppName}-info-ag'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: defaultInfoActionGroupShortName
    enabled: true
    emailReceivers: [
      {
        name: 'info-email'
        emailAddress: defaultAlertNotificationEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

var effectiveOperationalActionGroupResourceIds = createDefaultActionGroups
  ? concat(operationalActionGroupResourceIds, [defaultOperationalActionGroup.id])
  : operationalActionGroupResourceIds

var effectiveInfoActionGroupResourceIds = createDefaultActionGroups
  ? concat(infoActionGroupResourceIds, [defaultInfoActionGroup.id])
  : infoActionGroupResourceIds

// ── Storage Account (required by Azure Functions runtime) ────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: length(storageAccountName) > 24 ? substring(storageAccountName, 0, 24) : storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }
}

// ── Log Analytics Workspace ──────────────────────────────────────────────────
// Backend for Application Insights. Workspace-based AppInsights is the modern
// approach (classic components are deprecated).
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    // 30 days is the minimum; first 5 GB/month per workspace is free.
    retentionInDays: 30
  }
}

// ── Application Insights ─────────────────────────────────────────────────────
// When APPLICATIONINSIGHTS_CONNECTION_STRING is set, the Azure Functions Node.js
// runtime instruments automatically — no code changes needed. Captured data:
//   • invocations as "requests" (duration, success, HTTP status)
//   • outbound Graph API calls as "dependencies" (URL, latency, status)
//   • context.log/warn/error() as "traces" (incl. Graph requestId)
//   • unhandled exceptions as "exceptions"
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    RetentionInDays: 30
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ── Consumption App Service Plan ─────────────────────────────────────────────
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

// ── Azure Maps account (optional; used by inline map preview in SPFx card) ───
resource azureMapsAccount 'Microsoft.Maps/accounts@2023-06-01' = if (deployAzureMaps) {
  name: azureMapsName
  location: location
  tags: tags
  sku: {
    name: 'G2'
  }
  kind: 'Gen2'
  properties: {
    disableLocalAuth: false
  }
}

// ── Function App ─────────────────────────────────────────────────────────────
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        // Identity-based storage connection — no account key stored anywhere.
        // The three role assignments below grant the Managed Identity the minimum
        // required access to blob, queue, and table services.
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~22'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: packageUrl
        }
        {
          name: 'TENANT_ID'
          value: tenantId
        }
        {
          name: 'ALLOWED_AUDIENCE'
          value: 'api://guest-sponsor-info-proxy/${functionClientId}'
        }
        {
          name: 'CORS_ALLOWED_ORIGIN'
          value: 'https://${tenantName}.sharepoint.com'
        }
        {
          name: 'SPONSOR_LOOKUP_TIMEOUT_MS'
          value: '5000'
        }
        {
          name: 'BATCH_TIMEOUT_MS'
          value: '4000'
        }
        {
          name: 'PRESENCE_TIMEOUT_MS'
          value: '2500'
        }
        {
          name: 'NODE_ENV'
          value: 'production'
        }
        {
          // When set, the Azure Functions Node.js runtime automatically sends all
          // invocation traces, outbound dependencies, and exceptions to AppInsights.
          // No application code changes are required.
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
      cors: {
        allowedOrigins: [
          'https://${tenantName}.sharepoint.com'
        ]
        supportCredentials: false
      }
    }
  }
}

// ── EasyAuth – Microsoft Entra ID provider ───────────────────────────────────
resource authSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  name: 'authsettingsV2'
  parent: functionApp
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: functionClientId
          openIdIssuer: 'https://sts.windows.net/${tenantId}/'
        }
        validation: {
          allowedAudiences: [
            'api://guest-sponsor-info-proxy/${functionClientId}'
          ]
        }
      }
    }
    login: {
      tokenStore: {
        enabled: false
      }
    }
  }
}

// ── Storage role assignments (Managed Identity auth, no key required) ────────
// The Consumption plan runtime needs blob, queue, and table access.
// 'Owner' (or a custom role with Microsoft.Authorization/roleAssignments/write)
// is required on the deploying principal to create these assignments.
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var storageTableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'

resource storageBlobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, storageBlobDataOwnerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageQueueRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, storageQueueDataContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageTableRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, storageTableDataContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageTableDataContributorRoleId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Optional KQL alerts (low false-positive model) ───────────────────────────
resource serviceOutageAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = if (enableServiceOutageAlert) {
  name: '${functionAppName}-service-outage-kql'
  location: location
  tags: tags
  properties: {
    description: 'Operational email alert for probable service outage (5xx/504 spike or low success rate).'
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT${alertEvaluationFrequencyInMinutes}M'
    windowSize: 'PT${alertWindowInMinutes}M'
    severity: 2
    criteria: {
      allOf: [
        {
          query: serviceOutageAlertQuery
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
    actions: {
      actionGroups: effectiveOperationalActionGroupResourceIds
    }
    autoMitigate: true
  }
}

resource authConfigRegressionAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = if (enableAuthConfigRegressionAlert) {
  name: '${functionAppName}-auth-config-regression-kql'
  location: location
  tags: tags
  properties: {
    description: 'Operational email alert for auth/config regressions (AUTH_CONFIG_* reason codes).'
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT${alertEvaluationFrequencyInMinutes}M'
    windowSize: 'PT${alertWindowInMinutes}M'
    severity: 2
    criteria: {
      allOf: [
        {
          query: authConfigRegressionAlertQuery
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
    actions: {
      actionGroups: effectiveOperationalActionGroupResourceIds
    }
    autoMitigate: true
  }
}

resource likelyAttackInfoAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = if (enableLikelyAttackInfoAlert) {
  name: '${functionAppName}-likely-attack-info-kql'
  location: location
  tags: tags
  properties: {
    description: 'Info-only alert for likely attack/noise spikes (high 401/403 from many IPs).'
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT${alertEvaluationFrequencyInMinutes}M'
    windowSize: 'PT${alertWindowInMinutes}M'
    severity: 4
    criteria: {
      allOf: [
        {
          query: likelyAttackInfoAlertQuery
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
    actions: {
      actionGroups: effectiveInfoActionGroupResourceIds
    }
    autoMitigate: true
  }
}

// ── Outputs ──────────────────────────────────────────────────────────────────
@description('The URL of the deployed Function App.')
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'

@description('The function endpoint URL to paste into the SPFx web part property pane.')
output sponsorApiUrl string = 'https://${functionApp.properties.defaultHostName}/api/getGuestSponsors'

@description('Object ID of the system-assigned Managed Identity — needed for setup-graph-permissions.ps1.')
output managedIdentityObjectId string = functionApp.identity.principalId

@description('Name of the Application Insights component — open in the Azure Portal for live telemetry.')
output appInsightsName string = appInsights.name

@description('Azure Maps account name (empty when deployAzureMaps=false).')
output azureMapsAccountName string = deployAzureMaps ? azureMapsAccount.name : ''

@description('Azure CLI command to fetch the Azure Maps primary key (empty when deployAzureMaps=false).')
output azureMapsKeyCommand string = deployAzureMaps
  ? 'az maps account keys list -g ${resourceGroup().name} -n ${azureMapsAccount.name} --query primaryKey -o tsv'
  : ''
