# LogInsight
# https://192.168.100.111/rest-api#Getting-started-with-the-Log-Insight-REST-API

################################################
# Configure the variables below for the Server
################################################
$vLIServer = "192.168.100.111"
$vLIProvider = "Local"
# $vLIProvider = "ActiveDirectory"
################################################
# Nothing to configure below this line - Starting the main function of the script
################################################
# Prompting for credentials
$Credentials = Get-Credential -Credential $null
$vLIUser = $Credentials.UserName
$Credentials.Password | ConvertFrom-SecureString
$vLIPassword = $Credentials.GetNetworkCredential().password
################################################
# Adding certificate exception to prevent API errors
################################################
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'

################################################
# Building API string & invoking REST API
################################################
$vLIBaseAuthURL = "https://" + $vLIServer + ":9543/api/v1/sessions"
$vLIBaseURL = "https://" + $vLIServer + ":9543/api/v1/"

$Type = "application/json"
# Creating JSON for Auth Body
$vLIAuthJSON =
"{
  ""username"": ""$vLIUser"",
  ""password"": ""$vLIPassword"",
  ""provider"": ""$vLIProvider""
}"
# Authenticating with API
Try 
{
    $vLISessionResponse = Invoke-RestMethod -Method POST -Uri $vLIBaseAuthURL -Body $vLIAuthJSON -ContentType $Type
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
$vLISessionHeader = @{"Authorization"="Bearer "+$vLISessionResponse.SessionId}
Write-Host -ForegroundColor White '---'


################################################
# Building API string & invoking REST API, 
# Log Insight Version
################################################
$URL = $vLIBaseURL+"version"

Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
    $LIVersion = $JSON.Version
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
Write-Host -ForegroundColor Cyan 'Version'
$LIVersion
Write-Host -ForegroundColor White '---'


################################################
# Building API string & invoking REST API, 
# NTP config
################################################
$URL = $vLIBaseURL+"time/config"

Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
    $NtpServers = $JSON.ntpConfig.ntpServers
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
Write-Host -ForegroundColor Cyan 'NTP servers'
$NtpServers
Write-Host -ForegroundColor White '---'


################################################
# Authgroups
# Shows Directory Groups and Permissions (called capabilities)
# But does not show the Role name.
################################################

$URL = $vLIBaseURL+"authgroups/ad" # provider must be added "ad" or "vidm"

Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
    $AuthProviderGroups = $JSON.authProviderGroups
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

$Accounts = @()
Foreach ($group in $AuthproviderGroups) {
    # Determine Group Type; local Group or Active Directory
    $new = [PSCustomObject]@{
        Name        = $group.name
        Id          = $group.groupIds
        IsGroup     = $true
        Type        = 'ActiveDirectory'
        roleNames   = ''
        permissions = $group.capabilities
    }
    $Accounts += $new
}

Write-Host -ForegroundColor Cyan 'Directory Groups'
$Accounts
Write-Host -ForegroundColor White '---'


################################################
# Users 
################################################

$URL = $vLIBaseURL+"users"

Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
    $Users = $JSON.Users
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

Write-Host -ForegroundColor Cyan 'All Users'
$users
Write-Host -ForegroundColor White '---'


$userscapabilities = @()
foreach ($user in $users) {
    if ($user.type -eq "DEFAULT") {
        $id = $user.id
        $JSON = Invoke-RestMethod -Method GET -Uri $url"/"$id"/capabilities" -Headers $vLISessionHeader -ContentType $Type
        $new = [PSCustomObject]@{
            Name        = $user.username
            Id          = $user.id
            IsGroup     = $false
            Type        = 'Local'
            roleNames   = ''
            permissions = $JSON.capabilities
        }
        $userscapabilities += $new
    }
}

Write-Host -ForegroundColor Cyan 'Local Users'
$userscapabilities
Write-Host -ForegroundColor White '---'



################################################
# Roles
################################################

$URL = $vLIBaseURL+"roles"

Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
    $roles = $JSON.Roles
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

$rolescapabilities = @()
foreach ($role in $roles) {
    $id = $role.id
    $JSON = Invoke-RestMethod -Method GET -Uri $url"/"$id"/capabilities" -Headers $vLISessionHeader -ContentType $Type
    $new = [PSCustomObject]@{
        rolename = $role.name
        description = $role.description
        capabilities = $JSON.capabilities
    }
    $rolescapabilities += $new
}


Write-Host -ForegroundColor Cyan 'All Roles'
$rolescapabilities
Write-Host -ForegroundColor White '---'




