@allowed([
  'dev'
  'test'
  'acc'
  'prod'
])
param environmentSlot string = 'prod'
param system string

@allowed([
  'standard'
  'premium'
])
param sku string = 'standard'

var keyVaultName = '${system}-${environmentSlot}-kv'

resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: sku
    }
    accessPolicies: []
    enableSoftDelete: false
  }
}

output keyVaultName string = keyVault.name
output keyVaultUrl string = 'https://${keyVault.name}.vault.azure.net'
