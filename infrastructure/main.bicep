param systemName string = 'f1func'
@allowed([
  'dev'
  'test'
  'acc'
  'prod'
])
param environmentName string = 'dev'
param azureRegion string = 'weu'

param developerObjectIds array = [
  'ce00c98d-c389-47b0-890e-7f156f136ebd'
  '4511674d-9538-4852-a05d-4416c894aeb8'
  'ad7deb2e-6a44-4309-a037-6f0ff6b273b2'
  'f2256599-cbea-44ae-aa54-2daafaac605a'
]
var webAppName = '${systemName}-${environmentName}-${azureRegion}-app'

resource webApiStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: 'f1mandevweu'
  scope: resourceGroup('F1Manager-Dev-Api')
}

module storageModule 'Storage/storageAccounts.bicep' = {
  name: 'storageModule'
  params: {
    environmentName: environmentName
    systemName: systemName
    azureRegion: azureRegion
  }
}

module applicationInsights 'Insights/components.bicep' = {
  name: 'applicationInsightsDeploy'
  params: {
    environmentName: environmentName
    systemName: systemName
    azureRegion: azureRegion
  }
}

module keyVault 'KeyVault/vaults.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    environmentName: environmentName
    systemName: systemName
    azureRegion: azureRegion
  }
}

// var secretsArray = union(storage.outputs.secret, messaging.outputs.secrets)

module secretsModule 'KeyVault/vaults/secrets.bicep' = {
  dependsOn: [
    keyVault
  ]
  name: 'secretsModule'
  params: {
    keyVault: keyVault.outputs.keyVaultName
    secrets: storageModule.outputs.secret
  }
}
module externalSecretsModule 'KeyVault/vaults/secret.bicep' = {
  dependsOn: [
    keyVault
  ]
  name: 'externalSecretsModule'
  params: {
    keyVault: keyVault.outputs.keyVaultName
    secretName: 'ComponentImagesStorageAccount'
    secretValue: 'DefaultEndpointsProtocol=https;AccountName=${webApiStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(webApiStorageAccount.id, webApiStorageAccount.apiVersion).keys[0].value}'
  }
}

module appServicePlanModule 'Web/serverfarms.bicep' = {
  dependsOn: [
    storageModule
  ]
  name: 'appServicePlanModule'
  params: {
    environmentName: environmentName
    systemName: systemName
    azureRegion: azureRegion
    kind: 'functionapp'
    sku: {
      name: 'F1'
      capacity: 0
    }
  }
}

module functionAppModule 'Web/sites.bicep' = {
  dependsOn: [
    appServicePlanModule
    storageModule
  ]
  name: 'functionAppModule'
  params: {
    appServicePlanId: appServicePlanModule.outputs.id
    webAppName: webAppName
    kind: 'functionapp'
    alwaysOn: false
  }
}

resource config 'Microsoft.Web/sites/config@2020-12-01' = {
  dependsOn: [
    keyVaultAccessPolicy
    functionAppModule
    secretsModule
    externalSecretsModule
  ]
  name: '${webAppName}/web'
  properties: {
    appSettings: [
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        value: applicationInsights.outputs.instrumentationKey
      }
      {
        name: 'AzureWebJobsStorage'
        value: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.keyVaultUrl}/secrets/${storageModule.outputs.secretName})'
      }
      {
        name: 'FUNCTIONS_EXTENSION_VERSION'
        value: '~3'
      }
      {
        name: 'FUNCTIONS_WORKER_RUNTIME'
        value: 'dotnet'
      }
      {
        name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
        value: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.keyVaultUrl}/secrets/${storageModule.outputs.secretName})'
      }
      {
        name: 'ComponentImagesStorageAccount'
        value: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.keyVaultUrl}/secrets/ComponentImagesStorageAccount)'
      }
      {
        name: 'WEBSITE_CONTENTSHARE'
        value: 'azure-function'
      }
    ]
  }
}

module keyVaultAccessPolicy 'KeyVault/vaults/accessPolicies.bicep' = {
  name: 'keyVaultAccessPolicyDeploy'
  dependsOn: [
    keyVault
    functionAppModule
  ]
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    principalId: functionAppModule.outputs.servicePrincipal
  }
}

@batchSize(1)
module developerAccessPolicies 'KeyVault/vaults/accessPolicies.bicep' = [for developer in developerObjectIds: {
  name: 'developer${developer}'
  dependsOn: [
    keyVault
    keyVaultAccessPolicy
  ]
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    principalId: developer
  }
}]
