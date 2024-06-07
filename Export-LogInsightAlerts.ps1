# Export-LogInsightAlerts.ps1

<#
.SYNOPSIS
  Script will export all Alerts configured in a Log Insight cluster
  Webhooks are also exported, reason: during import the WebhookId needs to be converted
  WebhookIds are unique for each cluster and need to be converted during import

.INPUT
  Configure var for exporting Alerts.

  Credentials
  Use account with admin privileges, like local admin.

.OUTPUT
  Two files:
  export_alerts.json: exported alerts in .json format
  export_webhooks.json: exported webhooks in .json format

.EXAMPLE
  Run script.

#>


###############################################################
# Vars
###############################################################

# The cluster where the Alerts will be exported
$vLIServer = 'loginsight.acme.com'

###############################################################
# Nothing to configure below this line - Starting the main function of the script
###############################################################

###############################################################
# Handle Authentication, assume same credentials for all clusters
###############################################################
# The easy way, DO NOT use outside lab!
$vLIUser = 'admin'
$vLIPassword = 'VMware1!'
# IMPORTANT PARAMETER: Provider (Local, vIDM or ActiveDirectory)
$vLIProvider = "Local"

################################################
# Adding certificate exception to prevent API errors
################################################
if ($PSVersionTable.PSVersion.Major -like "5") {
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
}


################################################
# Building API string & invoking REST API
################################################
$vLIBaseAuthURL = "https://" + $vLIServer + ":9543/api/v2/sessions"
$vLIBaseURL = "https://" + $vLIServer + ":9543/api/v2/"
$Type = "application/json"

# Creating JSON for Auth Body
$vLIAuthJSON = @{
    username = $vLIUser
    password = $vLIPassword
    provider = $vLIProvider
} | ConvertTo-Json -Depth 2

# Authenticating with API
Try {
    $vLISessionResponse = Invoke-RestMethod -Method POST -Uri $vLIBaseAuthURL -Body $vLIAuthJSON -ContentType $Type
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
$vLISessionHeader = @{"Authorization" = "Bearer " + $vLISessionResponse.SessionId }


################################################
# Log Insight Version
################################################
$URL = $vLIBaseURL + "version"
Try {
    $JSON = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}
Write-Host "Log Insight Version: $($JSON.Version)"


################################################
# Log Insight Get Alerts
################################################
$Alerts = ''
$URL = $vLIBaseURL + "alerts"
Try {
    $Alerts = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
    # Convert to .json file for later use, only enabled alerts!
    $Alerts | Where-Object { $_.enabled -eq "True" } | ConvertTo-Json -Depth 6 > export_alerts.json
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}


################################################
# Log Insight Get Webhooks
################################################
$Webhooks = ''
$URL = $vLIBaseURL + "notification/webhook"
Try {
    $Webhooks = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
    $Webhooks | ConvertTo-Json -Depth 6 > export_webhooks.json
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

#eof