function Export-IntuneDeviceConfigurationPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $ExportFileName
    )
    . $PSScriptRoot\Get-IntuneDeviceConfigurationPoliciesAssignments.ps1

    #Requires -Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore, Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement
    Import-Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore, Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement

    #region CommonVariables
    $WorkingDirectory = $PSScriptRoot 
    $CurrentDate = Get-Date
    if ($ExportFileName) {
        $ReportName = $ExportFileName
    }
    else{
        $ReportName = "IntunePoliciesAssignments_$($CurrentDate.toString("yyyy-MM-dd")).json"
    }
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
        Connect-MGGraph -ForceRefresh -UseDeviceAuthentication -ErrorAction "STOP" | Out-Null
        Select-MgProfile "Beta"
        Write-Log "Connection has been established"
    }
    catch{
        Write-Log "Connection hasn't been established. $($_.Exception)" -level ERROR
        break
    }

    $Assignments = Get-IntuneDeviceConfigurationPoliciesAssignments

    ConvertTo-Json $Assignments -Depth 3 | Out-File $ReportName 
    
}
