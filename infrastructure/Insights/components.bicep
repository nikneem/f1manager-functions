@allowed([
  'dev'
  'test'
  'acc'
  'prod'
])
param environmentSlot string = 'prod'
param system string

var applicationInsightsName = '${system}-${environmentSlot}-ai'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  kind: 'web'
  location: resourceGroup().location
  name: applicationInsightsName
  properties: {
    Application_Type: 'web'
  }
}

output applicationInsightsName string = applicationInsightsName
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
