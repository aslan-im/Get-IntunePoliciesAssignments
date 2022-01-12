[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType 'leaf'})]  
    [string] 
    $AssignmentsPath  
)

. $PSScriptRoot\Get-IntuneDeviceConfigurationPoliciesAssignments.ps1

#Requires -Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore, Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement
Import-Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore, Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement

#region CommonVariables
$WorkingDirectory = $PSScriptRoot 
$CurrentDate = Get-Date
#endregion

#region LoggingConfiguration
$LogFilePath = "$WorkingDirectory\logs\log_$($CurrentDate.ToString("yyyy-MM-dd")).log"
Set-LoggingDefaultLevel -Level 'Info'
Add-LoggingTarget -Name File -Configuration @{
    Path        = $LogFilePath
    PrintBody   = $false
    Append      = $true
    Encoding    = 'ascii'
}

Add-LoggingTarget -Name Console -Configuration @{}
#endregion

write-log "Connecting to the Graph"
try{
    Connect-MGGraph -ForceRefresh -UseDeviceAuthentication -ErrorAction "STOP"
    Select-MgProfile "Beta"
    Write-Log "Connection has been established"
}
catch{
    Write-Log "Connection hasn't been established. $($_.Exception)" -level ERROR
    break
}

Write-Log 'Getting assignments from cloud'
try {
    $AssignmentsCloud = Get-IntuneDeviceConfigurationPoliciesAssignments -ErrorAction 'Stop'
    Write-Log "Getting assignments from the cloud"
}
catch {
    Write-Log "Unable to get the assignments from cloud" -Level ERROR
    break
}

Write-Log "Reading assignments from file"
try{
    $AssignmentsFile = Get-Content $AssignmentsPath -ErrorAction "STOP" | ConvertFrom-Json
    Write-Log "Assignments have been loaded"
}
catch{
    Write-Log "Unable to read assignments from file. $($_.Exception)"
    break
}

if($AssignmentsCloud -and $AssignmentsFile) {
    $AssignmentsDifferences = Compare-Object -ReferenceObject $AssignmentsFile  -DifferenceObject $AssignmentsCloud
    Write-Output $AssignmentsDifferences
}
