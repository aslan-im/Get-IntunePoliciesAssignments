function Get-IntuneDeviceConfigurationPoliciesAssignments {
    [CmdletBinding()]
    param ()
    #Requires -Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore, Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement
    Import-Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore, Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement

    #region CommonVariables
    $WorkingDirectory = $PSScriptRoot 
    #endregion

    try{
        Connect-MGGraph -ForceRefresh -UseDeviceAuthentication -ErrorAction "STOP" | Out-Null
        Select-MgProfile "Beta"
    }
    catch{
        throw $($_.Exception)
        break
    }

    try{
        $Policies = Get-MgDeviceManagementDeviceConfiguration -ErrorAction "STOP" | Select-Object DisplayName, Id
    }
    catch{
        throw $($_.Exception)
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

    return $Assignments

    try {
        ConvertTo-Json $Assignments -Depth 3 -ErrorAction "STOP" | Out-File $ReportName 
    }
    catch {
        throw $($_.Exception)
        break
    }

}


