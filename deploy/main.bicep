@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('The name of the Automation Account to deploy.')
param automationAccountName string = 'travit-aut-${uniqueString(resourceGroup().id)}'

@description('The name of the Automation Account to deploy. This name must be globally unique.')
param automationRunbookName string = 'travit-rb-${uniqueString(resourceGroup().id)}'

@description('The name of the storage account to deploy. This name must be globally unique.')
param keyVaultName string = 'travit-kv${uniqueString(resourceGroup().id)}'

@description('The name of the storage account to deploy. This name must be globally unique.')
param storageAccountName string = 'travit${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }

  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {
        enabled: true
        days: 30
      }
    }

    resource blobContainer 'containers' = {
      name: 'data'
      properties: {
        publicAccess: 'Container'
      }
    }
  }

  resource tableResource 'tableServices' = {
    name: 'default'
  }
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2019-06-01' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

resource automationRunbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: automationRunbookName
  location: location
  properties: {
    logVerbose: true
    logProgress: true
    runbookType: 'PowerShell'
    description: 'PowerShell script to put data into Table storage.'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: '7c2cecbb-4b12-4725-936b-ece52d4302a3'
    accessPolicies: [
      {
        tenantId: '7c2cecbb-4b12-4725-936b-ece52d4302a3'
        objectId: '8f9bdc89-d45a-420d-9d2a-da49568a316a'
        permissions: {
          keys: [
            'get'
          ]
          secrets: [
            'list'
            'get'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}
