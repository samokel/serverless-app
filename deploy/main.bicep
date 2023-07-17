@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('The Azure Tenant Id.')
param tenantId string = subscription().tenantId

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
    publishContentLink: {
      uri: 'uri'
      version: '1.0.0.0'
    }
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
    tenantId: tenantId
    // accessPolicies: [
    //   {
    //     tenantId: tenantId
    //     objectId: 'objectId'
    //     permissions: {
    //       keys: [
    //         'get'
    //       ]
    //       secrets: [
    //         'list'
    //         'get'
    //       ]
    //     }
    //   }
    // ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}
