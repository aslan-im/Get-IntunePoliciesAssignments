[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType 'leaf'})]  
    [string] 
    $AssignmentsPath  
)

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

Write-Log 'Reading assignments'
try {
    $Assignments = Get-Content $AssignmentsPath -ErrorAction 'Stop' | ConvertFrom-Json
    Write-Log "Assignments have been imported"
}
catch {
    Write-Log "Unable to import assignments file" -Level ERROR
    break
}

foreach($Assignment in $Assignments){
    $AssignmentSplat = @{
        DeviceConfigurationId = $Assignment.PolicyID
        TargetGroupId = $Assignment.TargetGroupId
        ExcludeGroup = $Assignment.ExcludeGroup
        ErroAction = "STOP"
    }
    try {
        Write-Log "Creating assignment $($Assignment.PolicyDisplayName)"
        New-MgDeviceManagementDeviceConfigurationGroupAssignment @AssignmentSplat
    }
    catch {
        Write-Log "Unable to create assignment. Policy: $($Assignment.PolicyDisplayName) TargetGroup: $($Assignment.TargetGroupId). `n$($_.Exception)"
    }
}

