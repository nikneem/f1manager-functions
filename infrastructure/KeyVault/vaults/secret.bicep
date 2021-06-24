param keyVault string
param secretName string
@secure()
param secretValue string

resource secretsLoop 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  name: '${keyVault}/${secretName}'
  properties: {
    value: secretValue
  }
}
