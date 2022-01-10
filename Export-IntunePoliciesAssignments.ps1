#Requires -Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore, Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement
Import-Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore, Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement

. $PSScriptRoot\Functions\Send-GraphEmail.ps1

#region Functions
function Get-IntunePolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $ParameterName
    )
}
#endregion

#region CommonVariables
$WorkingDirectory = $PSScriptRoot 
$CurrentDate = Get-Date
$ReportName = "IntunePoliciesAssignments_($CurrentDate.toString('yyyy-MM-dd')).json"
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

Write-Log "Getting the Intune policies"
try{
    $Policies = Get-MgDeviceManagementDeviceConfiguration -ErrorAction "STOP" | Select-Object DisplayName, Id
    Write-Log "Have found $($Policies.Count) policies"
}
catch{
    Write-Log "Unable to get the policies. $($_.Exception)" -level ERROR
    break
}

$Assignments = @()
foreach ($Policy in $Policies) {
    $SelectionSplat = @(
        @{L='PolicyDisplayName'; E={$Policy.DisplayName}},
        @{L='PolicyID';E={$Policy.Id}},
        'TargetGroupId',
        'ExcludeGroup'
    )    

    $Assignments += Get-MgDeviceManagementDeviceConfigurationGroupAssignment -DeviceConfigurationId $Policy.Id | Select-Object $SelectionSplat
}
ConvertTo-Json $Assignments -Depth 3 | Out-File $ReportName 