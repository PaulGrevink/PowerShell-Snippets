# Import-LogInsightAlerts.ps1

<#
.SYNOPSIS
  Script will import all Alerts from file export_alerts.json
  Webhooks are also exported, reason: during import the WebhookId needs to be converted
  WebhookIds are unique for each cluster and need to be converted during import


.INPUT
  Two files are needed:
  export_alerts.json: exported alerts in .json format
  export_webhooks.json: exported webhooks in .json format

  Credentials
  Use account with admin privileges, like local admin.

.OUTPUT
  All new created Alerts will be exported as a .json file named: newAlerts.json

.EXAMPLE
  Run script.

#>


###############################################################
# Vars
###############################################################

# The cluster where the Alerts will be imported
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


# We need the exported Alerts and the Webhooks
# Webhooks are needed to get the correct Webhook Id
$exportAlerts = Get-Content ("$($PSScriptRoot)\export_alerts.json") | ConvertFrom-Json
$exportWebhooks = Get-Content ("$($PSScriptRoot)\export_webhooks.json") | ConvertFrom-Json


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


# We need webhooks for the destination so we can replace the webhook Id
################################################
# Log Insight Get Webhooks
################################################

$NewWebhooks = ''
$URL = $vLIBaseURL + "notification/webhook"
Try {
    $NewWebhooks = Invoke-RestMethod -Method GET -Uri $URL -Headers $vLISessionHeader -ContentType $Type
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

[Array]$NewAlerts = @()

foreach ($alert in $exportalerts) {
    $NewAlert = [PSCustomObject]@{
        name           = ''
        info           = ''
        recommendation = ''
        enabled        = ''
        recipients     = ''
        type           = ''
        hitCount       = ''
        hitOperator    = ''
        searchPeriod   = ''
        searchInterval = ''
        query          = ''
    }

    $NewAlert.name = $alert.name
    $NewAlert.info = $alert.info
    $NewAlert.recommendation = $alert.recommendation
    $NewAlert.enabled = $alert.enabled
    $NewAlert.recipients = $alert.recipients
    $NewAlert.type = $alert.type
    $NewAlert.hitCount = $alert.hitCount
    $NewAlert.hitOperator = $alert.hitOperator
    $NewAlert.searchPeriod = $alert.searchPeriod
    $NewAlert.searchInterval = $alert.searchInterval
    $NewAlert.query = $alert.query

    # Replace WebhookId
    [Array]$NewWebhookids = @()
    $ids = $alert.recipients.webhookIds
    if ($ids.count -gt 0) {
        foreach ($id in $ids) {
            $WebhookName = ($exportWebhooks | Where-Object { $_.id -eq $id }).name
            $NewWebhookid = ($NewWebhooks | Where-Object { $_.name -eq $WebhookName }).id
            $NewWebhookids += $NewWebhookid
        }
        $NewAlert.recipients.webhookIds = $NewWebhookids
    }
    $NewAlerts += $NewAlert

    # Add Alert
    $URL = $vLIBaseURL + "alerts"
    $body_json = $NewAlert | ConvertTo-Json -Depth 2

    Try {
        Invoke-RestMethod -Method POST -Uri $URL -Headers $vLISessionHeader -Body $body_json -ContentType $Type
    }
    Catch {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
    }

} # End foreach loop
$NewAlerts | ConvertTo-Json -Depth 6 > newAlerts.json

#eof