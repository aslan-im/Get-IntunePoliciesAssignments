#Requires -Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore
Import-Module Logging, GraphApiRequests, Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore

. $PSScriptRoot\Functions\Send-GraphEmail.ps1

#region Functions
function Example-GraphApiFunction {
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
$ConfigPath = "$WorkingDirectory\config\config.json"
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

Write-Log "Checking config file"
$ConfigFileExists = Test-Path $ConfigPath

if ($ConfigFileExists) {
    Write-Log "Getting config file content"
    try{
        $Config = Get-Content $ConfigPath -ErrorAction Stop | ConvertFrom-Json
        Write-Log "Config file has been successfull read"
    }
    catch{
        Write-Log "Unable to read the config file. $($_.Exception.Message)" -Level ERROR
        throw "Unable to read the config file. $($_.Exception.Message)"
        break
    }
}
else{
    Write-Log -Level ERROR "Config file doesn't exist. Please check the path: $ConfigPath" -Level ERROR
    throw "Unable to read the config file. $($_.Exception.Message)"
    break
}

#region ConfigVariables
$SecretsVaultName       = $Config.secretsConfig.secretVaultName
$ClientId               = $Config.apiConfig.clientId
$TenantId               = $Config.apiConfig.tenantId
$ClientSecretSecretName = $Config.apiConfig.clientSecretSecretName

#Mail configuration
$MailSender        = $Config.mailConfig.sender
$MailRecipients    = $Config.mailConfig.recipients
$MailCCRecipients  = $Config.mailConfig.copyRecipients
$MailBCCRecipients = $Config.mailConfig.copyRecipients
#endregion

write-log "Checking SecretVault status"
$IsSecretVaultHealthy = Test-SecretVault $SecretsVaultName

if ($IsSecretVaultHealthy) {
    Write-Log "Secret Vault is healthy"
}
else{
    Write-log -level ERROR "Secret vault is not healthy. Please check vault $SecretsVaultName"
    break
}

try {
    Write-Log "Getting client secret from secret store vault"
    $ClientSecretSecureString = Get-Secret -Name $ClientSecretSecretName -Vault $SecretsVaultName -ErrorAction Stop 
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecretSecureString)
    $ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    Write-Log "Secret has been found and saved to variable"
}
catch {
    Write-Log "Unable to read the client secret value. Please check secret: $ClientSecretSecretName in secret vault: $SecretsVaultName"
}

write-log "Getting Graph API Token"
$TokenGettingCounter = 0
$Token = $null
do {
    ++$TokenGettingCounter
    try{
        Write-Log "Getting token attempt: $TokenGettingCounter"
        $Token = Get-GraphToken -AppId $ClientId -TenantID $TenantId -AppSecret $ClientSecret -ErrorAction Stop 
        Write-log "Token successfully collected"
        $TokenGettingCounter = 7
    }
    catch{
        write-log -Level Error "Token was not received. $($_.Exception)"
    }

} while ($null -eq $Token -and $TokenGettingCounter -lt 6)

if ($Null -eq $Token){
    Write-Log -level Error "Was unable to get the token"
    break
}

#region SendEmail 
$SendEmailSplat = @{
    SenderUpn = $MailSender
    Recipients = $MailRecipients 
    CopyRecipients = $MailCCRecipients 
    HidenRecipients = $MailBCCRecipients
    MailSubject = ""
    MessageBody = ""
    AttachmentPaths = ""
    Token = ""
    ErrorAction = "STOP"
}
try{
    Send-GraphEmail @SendEmailSplat -Verbose
}
catch {
    Write-Log -level Error $_.Exception.message
}
#endregion