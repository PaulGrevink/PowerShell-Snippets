<#
Get-ClusterRules

#>

<#
$creds = Get-Credential -UserName administrator@vsphere.local

Connect-VIServer -Server 192.168.100.101 -Credential $creds
#>


$clusters = Get-Cluster |Sort-Object $_.Name | Select-Object -ExpandProperty Name
foreach ($cluster in $clusters) {
    Write-Host "Cluster    : "$cluster
    Write-Host "  1. Get all Cluster Groups"
    $rules1 = Get-DrsClusterGroup -Cluster $cluster -Type All | Sort-Object $_.Name
    foreach ($rule in $rules1) {
        Write-Host "    Name       : "$rule.Name
        Write-Host "    GroupType  : "$rule.GroupType
        foreach ($i in $rule.Member) {
            Write-Host "    Member     : "$i.Name
        }
        Write-Host "  -----------------------------------------------------"
    }

    Write-Host "  2. Get all Cluster Rules"
    $rules2 = Get-DrsVMHostRule -Cluster $cluster | Sort-Object $_.Name
    foreach ($rule in $rules2) {
        Write-Host "    Name       : "$rule.Name
        Write-Host "    VMGroup    : "$rule.VMGroup
        Write-Host "    Type       : "$rule.Type
        Write-Host "    VMHostGroup: "$rule.VMHostGroup
        Write-Host "    Enabled    : "$rule.Enabled
        Write-Host "  -----------------------------------------------------"
    }

    Write-Host "  3. Get all Affinity rules"
    $rules3 = Get-DrsRule -Cluster $cluster | Sort-Object $_.Name
    foreach ($rule in $rules3) {
        Write-Host "    Name       : "$rule.Name
        Write-Host "    Type       : "$rule.Type
        Write-Host "    Enabled    : "$rule.Enabled
        foreach ($i in $rule.VMIDs) {
            Write-Host "    VM         : "(Get-VM -Id $i).Name
        }
        Write-Host "  -----------------------------------------------------"
    }
    Write-Host "  "
}


#eof