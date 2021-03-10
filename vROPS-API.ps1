# https://virtuallysober.com/2018/08/02/using-vrops-6-7-rest-apis-in-powershell-servicenow-integration/

################################################
# Configure the variables below for vROPs
################################################
$vROPsServer = "192.168.100.121"
# Set the correct Authentication Source for log in. Uncomment one entry
$AuthSource = "Local"            # For Local accounts
# $AuthSource = "ActiveDirectory" # For Active Directory accounts
################################################
# Nothing to configure below this line 
################################################

# Prompting for credentials
$vROPsCredentials = Get-Credential -Message "Enter your vROPs credentials"
$vROPSUser = $vROPsCredentials.UserName
$vROPsCredentials.Password | ConvertFrom-SecureString
$vROPsPassword = $vROPsCredentials.GetNetworkCredential().password

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
# Building vROPS API string & invoking REST API
################################################
$BaseURL = "https://" + $vROPsServer + "/suite-api/api/"
$BaseAuthURL = "https://" + $vROPsServer + "/suite-api/api/auth/token/acquire"
$Type = "application/json"

# Creating JSON for Auth Body
$AuthJSON =
"{
  ""username""  : ""$vROPSUser"",
  ""password""  : ""$vROPsPassword"",
  ""AuthSource"": ""$AuthSource""
}"
# Authenticating with API
Try 
{
    $vROPSSessionResponse = Invoke-RestMethod -Method POST -Uri $BaseAuthURL -Body $AuthJSON -ContentType $Type
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
# Extracting the session ID from the response
$vROPSSessionHeader = @{"Authorization"="vRealizeOpsToken "+$vROPSSessionResponse.'auth-token'.token
"Accept"="application/json"}


###############################################
# Getting Current vROPS version
###############################################
$URL = $BaseURL+"versions/current"
Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vROPSSessionHeader -ContentType $Type
    $VersionCurrent = $JSON
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

Write-Host -ForegroundColor Cyan 'Version'
$VersionCurrent.releasename
Write-Host -ForegroundColor White '---'


###############################################
# Getting User Groups (AD)
###############################################
$URL = $BaseURL+"auth/usergroups"
Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vROPSSessionHeader -ContentType $Type
    $AuthUserGroups = $JSON
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
$UserGroups = $AuthUserGroups.userGroups

$Accounts = @()
Foreach ($group in $UserGroups) {
    # Determine Group Type; local Group or Active Directory
    if ($group.name.Substring(0,3) -eq 'CN=') {
        $groupnameshort = ($group.name.Substring(0,($group.name.IndexOf(",")))).trim('CN=')
        $type = 'ActiveDirectory'
    } else {
        $groupnameshort = $group.name
        $type = 'Local'
    }
    $new = [PSCustomObject]@{
        Name        = $groupnameshort
        NameLong    = $group.name
        Id          = $group.id
        IsGroup     = $true
        Type        = $type
        roleNames   = $group.roleNames
        permissions = ''
    }
    $Accounts += $new
}

# Get permissions for the all roles attached to a group
foreach ($group in $Accounts) {
    $permissions = @()
    foreach ($role in $group.rolenames) {
        $JSON = Invoke-RestMethod -Method GET -Uri $BaseURL"auth/roles/"$role"/privileges" -Headers $vROPSSessionHeader -ContentType $Type
        $permissions += $JSON.privileges.key
    }
    $group.permissions = $permissions | Sort-Object -Unique
}

Write-Host -ForegroundColor Cyan 'UserGroups, Roles and Permissions'
$Accounts
Write-Host -ForegroundColor White '---'


###############################################
# Getting Local Users
###############################################
$URL = $BaseURL+"auth/users"
Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vROPSSessionHeader -ContentType $Type
    $AuthUsers = $JSON
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
$Users = $AuthUsers.users

$uAccounts = @()
Foreach ($user in $Users) {
    # Determine User Type; local Group or Active Directory
    # Active Directory users are imported, so skip.
    if ($user.distinguishedName.count -eq 1 ) {
        $type = 'ActiveDirectory'
        Continue
    } else {
        $type = 'Local'
    }

    $new = [PSCustomObject]@{
        Name        = $user.username
        NameLong    = ''
        Id          = $user.id
        IsGroup     = $false
        Type        = $type
        roleNames   = $user.roleNames
        permissions = ''
    }
    $uAccounts += $new
}

# Get permissions for the all roles attached to a group
foreach ($user in $uAccounts) {
    $permissions = @()
    foreach ($role in $user.rolenames) {
        if ($user.rolenames -eq 'Maintenance' -or $user.rolenames -eq 'Migration' -or $user.rolenames -eq 'Automation' ) {
            # permissions for these roles are not available, so skip.
            continue
        } else {
            $JSON = Invoke-RestMethod -Method GET -Uri $BaseURL"auth/roles/"$role"/privileges" -Headers $vROPSSessionHeader -ContentType $Type
            $permissions += $JSON.privileges.key
        }
    }
    $user.permissions = $permissions | Sort-Object -Unique
}

Write-Host -ForegroundColor Cyan 'Users, Roles and Permissions'
$uAccounts
Write-Host -ForegroundColor White '---'


###############################################
# Getting Roles
###############################################
$URL = $BaseURL+"auth/roles"
Try 
{
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vROPSSessionHeader -ContentType $Type
    $AuthRoles = $JSON
}
Catch 
{
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
$Roles = $AuthRoles.userRoles

Write-Host -ForegroundColor Cyan 'Roles'
$Roles
Write-Host -ForegroundColor White '---'


#eof