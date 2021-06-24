@allowed([
  'dev'
  'test'
  'acc'
  'prod'
])
param environmentSlot string = 'prod'
param system string
@allowed([
  'functionapp'
  'linux'
  'app'
])
param kind string = 'app'

param sku object = {
  name: 'Y1'
  capacity: 0
}

var servicePlanName = toLower('${system}-${environmentSlot}-serviceplan')

resource appFarm 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: servicePlanName
  location: resourceGroup().location
  kind: kind
  sku: {
    name: sku.name
    capacity: sku.capacity
  }
}

output servicePlanName string = servicePlanName
output id string = appFarm.id
