###########################################################################
## Azure automation runbook PowerShell script to export device data from ##
## Microsoft Intune / Endpoint Manager and dump it to Sharepoint Online  ##
###########################################################################

# Set some variables
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup = "BE-KBC-I-L01-R-XF9-MEM", # Reource group that hosts the storage account

    [Parameter(Mandatory=$false)]
    [string]$ProgressPreference = "SilentlyContinue"
)
$ProgressPreference = 'SilentlyContinue'
#$ResourceGroup = "BE-KBC-I-L01-R-XF9-MEM" # Reource group that hosts the storage account


####################
## AUTHENTICATION ##
####################

## Get MS Graph access token 
# Managed Identity
$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
$authHeader = @{
    'Authorization' = "Bearer $accessToken"
}


#########################
## GET DATA FROM GRAPH ##
#########################

$URI = "https://graph.microsoft.com/beta/deviceManagement/manageddevices"
$Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authHeader -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$DeviceData = $JsonResponse.value
If ($JsonResponse.'@odata.nextLink')
{
    do {
        $URI = $JsonResponse.'@odata.nextLink'
        $Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authHeader -UseBasicParsing 
        $JsonResponse = $Response.Content | ConvertFrom-Json
        $DeviceData += $JsonResponse.value
    } until ($null -eq $JsonResponse.'@odata.nextLink')
}


#############################################
## ORGANISE THE DATA INTO USEABLE DATASETS ##
#############################################

# Seperate by OS
$WindowsDevices = $DeviceData | Where-Object {$_.operatingSystem -eq "Windows"}
$iOSDevices = $DeviceData | Where-Object {$_.operatingSystem -eq "iOS"}
$AndroidDevices = $DeviceData | Where-Object {$_.operatingSystem -eq "Android"}
#$UnknownDevices = $DeviceData | where {$_.operatingSystem -ne "Android" -and $_.operatingSystem -ne "iOS" -and $_.operatingSystem -ne "Windows"}

# Set property exclusion lists. These properties will not be included in the final datasets.
$AndroidExcludedProperties = @(
    'activationLockBypassCode',
    'remoteAssistanceSessionUrl',
    'remoteAssistanceSessionErrorDetails',
    'configurationManagerClientEnabledFeatures',
    'deviceHealthAttestationState',
    'totalStorageSpaceInBytes',
    'freeStorageSpaceInBytes',
    'requireUserEnrollmentApproval',
    'iccid',
    'udid',
    'roleScopeTagIds',
    'windowsActiveMalwareCount',
    'windowsRemediatedMalwareCount',
    'configurationManagerClientHealthState',
    'configurationManagerClientInformation',
    'ethernetMacAddress',
    'physicalMemoryInBytes',
    'processorArchitecture',
    'specificationVersion',
    'skuFamily',
    'skuNumber',
    'managementFeatures',
    'hardwareInformation',
    'deviceActionResults',
    'chromeOSDeviceInfo',
    'retireAfterDateTime',
    'preferMdmOverGroupPolicyAppliedDateTime',
    'autopilotEnrolled',
    'managedDeviceId',
    'managedDeviceODataType',
    'managedDeviceReferenceUrl',
    'usersLoggedOn',
    'partnerReportedThreatState',
    'chassisType'
)

$iOSExcludedProperties = @(
    'activationLockBypassCode',
    'remoteAssistanceSessionUrl',
    'remoteAssistanceSessionErrorDetails',
    'configurationManagerClientEnabledFeatures',
    'deviceHealthAttestationState',
    'requireUserEnrollmentApproval',
    'iccid',
    'udid',
    'roleScopeTagIds',
    'windowsActiveMalwareCount',
    'windowsRemediatedMalwareCount',
    'configurationManagerClientHealthState',
    'configurationManagerClientInformation',
    'ethernetMacAddress',
    'physicalMemoryInBytes',
    'processorArchitecture',
    'specificationVersion',
    'skuFamily',
    'skuNumber',
    'managementFeatures',
    'hardwareInformation',
    'deviceActionResults',
    'chromeOSDeviceInfo',
    'retireAfterDateTime',
    'preferMdmOverGroupPolicyAppliedDateTime',
    'autopilotEnrolled',
    'managedDeviceId',
    'managedDeviceODataType',
    'managedDeviceReferenceUrl',
    'usersLoggedOn',
    'partnerReportedThreatState',
    'chassisType',
    'freeStorageSpaceInBytes',
    'totalStorageSpaceInBytes'
)

$WindowsExcludedProperties = @(
    'activationLockBypassCode'
    'chassisType'
    'jailBroken'
    'remoteAssistanceSessionUrl'
    'remoteAssistanceSessionErrorDetails'
    'phoneNumber'
    'androidSecurityPatchLevel'
    'deviceHealthAttestationState'
    'subscriberCarrier'
    'meid'
    'requireUserEnrollmentApproval'
    'iccid'
    'udid'
    'roleScopeTagIds'
    'configurationManagerClientInformation'
    'ethernetMacAddress'
    'physicalMemoryInBytes'
    'processorArchitecture'
    'specificationVersion'
    'managementFeatures'
    'hardwareInformation'
    'deviceActionResults'
    'usersLoggedOn'
    'chromeOSDeviceInfo'
    'totalStorageSpaceInBytes'
    'freeStorageSpaceInBytes'
    'configurationManagerClientEnabledFeatures'
    'configurationManagerClientHealthState'
    'managedDeviceId'
    'managedDeviceODataType'
    'managedDeviceReferenceUrl'
)

# Remove the unwanted properties and add some new ones
$AndroidDevices = $AndroidDevices | Select-Object -Property * -ExcludeProperty $AndroidExcludedProperties

$iOSDevices = $iOSDevices | Select-Object -Property *,`
@{l="freeStorageSpaceInGB";e={[math]::Round(($_.freeStorageSpaceInBytes / 1GB),2)}},`
@{l="totalStorageSpaceInGB";e={[math]::Round(($_.totalStorageSpaceInBytes / 1GB),2)}} `
-ExcludeProperty $iOSExcludedProperties

$WindowsDevices = $WindowsDevices | Select-Object -Property *,`
@{l="freeStorageSpaceInGB";e={[math]::Round(($_.freeStorageSpaceInBytes / 1GB),2)}},`
@{l="totalStorageSpaceInGB";e={[math]::Round(($_.totalStorageSpaceInBytes / 1GB),2)}}, `
@{l="daysSinceLastSync";e={[math]::Round(((Get-Date) - ($_.lastSyncDateTime | Get-Date -ErrorAction SilentlyContinue)).TotalDays,0)}}, `
@{l="enabledCoMgmtWorkloads_inventory";e={$_.configurationManagerClientEnabledFeatures.inventory}}, `
@{l="enabledCoMgmtWorkloads_modernApps";e={$_.configurationManagerClientEnabledFeatures.modernApps}}, `
@{l="enabledCoMgmtWorkloads_resourceAccess";e={$_.configurationManagerClientEnabledFeatures.resourceAccess}}, `
@{l="enabledCoMgmtWorkloads_deviceConfiguration";e={$_.configurationManagerClientEnabledFeatures.deviceConfiguration}}, `
@{l="enabledCoMgmtWorkloads_compliancePolicy";e={$_.configurationManagerClientEnabledFeatures.compliancePolicy}}, `
@{l="enabledCoMgmtWorkloads_windowsUpdateForBusiness";e={$_.configurationManagerClientEnabledFeatures.windowsUpdateForBusiness}}, `
@{l="enabledCoMgmtWorkloads_endpointProtection";e={$_.configurationManagerClientEnabledFeatures.endpointProtection}}, `
@{l="enabledCoMgmtWorkloads_officeApps";e={$_.configurationManagerClientEnabledFeatures.officeApps}}, `
@{l="MEMCMClient_state";e={$_.configurationManagerClientHealthState.state}}, `
@{l="MEMCMClient_errorCode";e={$_.configurationManagerClientHealthState.errorCode}}, `
@{l="MEMCMClient_lastSyncDateTime";e={$_.configurationManagerClientHealthState.lastSyncDateTime}}, `
@{l="MEMCMClient_daysSinceLastSync";e={[math]::Round(((Get-Date) - ($_.configurationManagerClientHealthState.lastSyncDateTime | Get-Date -ErrorAction SilentlyContinue)).TotalDays,0)}} `
 -ExcludeProperty $WindowsExcludedProperties

# Export the data to CSV format
$androiddevices | export-csv -Path $env:temp\AndroidDevices.csv -Force -NoTypeInformation  
$iOSDevices | export-csv -Path $env:temp\iOSDevices.csv -Force -NoTypeInformation 
$WindowsDevices | export-csv -Path $env:temp\WindowsDevices.csv -Force -NoTypeInformation 

write-output $androiddevices
write-output $iOSDevices
write-output $WindowsDevices

###########################################
## UPLOAD DATASETS TO Sharepoint         ##
###########################################
# PUT /drives/{drive-id}/items/{parent-id}:/{filename}:/content
#$URI = "https://graph.microsoft.com/v1.0/drives/b!1j2UrhH6hkGokOw_oSZL2YSdXcwyNLtGjNngstDGLR0VkZdty5pTTbGVp7Hve7vr/items/root:/WindowsDevices.csv:/content"
$URI = "https://graph.microsoft.com/v1.0/drives/b!1j2UrhH6hkGokOw_oSZL2YSdXcwyNLtGjNngstDGLR0VkZdty5pTTbGVp7Hve7vr/items/01NUSPGC2YKJ5W3GG4EFFY4RFMQ24AANRO:/WindowsDevices.csv:/content"

$SourceFile = "$env:temp\WindowsDevices.csv"
$FileStream = ([System.IO.FileInfo] (Get-Item $SourceFile)).OpenRead()

$Response = Invoke-WebRequest -Uri $URI -Method PUT -Headers $authHeader -Body $body -UseBasicParsing

#Close file stream
$FileStream.Close()
  
write-output "File has been uploaded!"