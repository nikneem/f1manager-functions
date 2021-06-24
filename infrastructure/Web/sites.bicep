param webAppName string
param appServicePlanId string
@allowed([
  'app'
  'functionapp'
])
param kind string = 'app'

param alwaysOn bool = true

resource webApp 'Microsoft.Web/sites@2020-12-01' = {
  name: webAppName
  location: resourceGroup().location
  kind: kind
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: alwaysOn
      ftpsState: 'Disabled'
      netFrameworkVersion: 'v5.0'
      http20Enabled: true
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output servicePrincipal string = webApp.identity.principalId
output webAppName string = webAppName
