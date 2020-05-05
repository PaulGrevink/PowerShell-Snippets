<#
     .SYNOPSIS
        This scripts read multiple .csv files containing setting - value pairs
        and creates new .csv file.

    .DESCRIPTION
        This scripts read multiple .csv files containing setting - value pairs
        from vCenter Servers (or other components) and creates an overview
        of all settings and values. Resulting .csv file can be used for the
        creation of a baseline document. 

    .SYNTAX
        No syntax, quick and dirty script file, sorry.

    .INPUT
        One or more .csv files stored in a folder defined by the variable $path.
        
        Naming convention for the .csv files: 
        The .csv files identify the vCenter Servers. 
        The part until the first dot will be used as a header in the output field
        Allowed names: vCenter01.csv or vCenter001.20200101.csv
        Not allowed names: 20200101.vCenter01.csv or vCenter01.txt

        The .csv files contains the result of Get-AdvancedSetting from a given vCenter Server.
        The .csv file must contain the following fields: Name, Type, Description and Value.
        Fields are seperated by a comma: , 
        
        Additional fields will be ignored.
        
        Description of the fields:
        Name, Name of the Setting e.g. 
        Type, Setting type e.g. String, Integer or Boolean
        Description, Description provided by VMware
        Value, actual value of the setting

    .OUTPUT
        Output is a .csv file named "VCsummary<yyyyMMdd_hhmm>.csv
        placed in the folder "C:\Temp.

     .EXAMPLE
		N/A.
#>

# $path, location where the .csv input files are stored.
$path = 'C:\Temp\vCenterSettings\'
# $csvall : All vCenter Severs
$csvall = Get-ChildItem -Path $path -File -Filter *.csv | Select-Object -ExpandProperty Name

# Read first file and create list of Names (of the Settings).
$csv = $csvall[0]
$impcsv = Import-Csv -Path $path$csv | ForEach-Object {
    [pscustomobject]@{
        Name = $_.Name
    }
}

# Read other files and add missing names to get ccomplete overview.
For ($i=1; $i -lt $csvall.count; $i++) {
    $csv = $csvall[$i]
    foreach ($row in Import-Csv -Path $path$csv) {
        if ($impcsv.Name -notcontains $row.name ) {
            $obj = New-Object -TypeName PSObject
            $obj | Add-Member -MemberType NoteProperty -Name Name -Value $row.name
            $impcsv += $obj
        }
    }
}

# Extend and fill everything with "NaN" or other defaults. 
# What stays NaN after finish, does not exist.
$impcsv | Add-Member -MemberType NoteProperty -Name Monitor -Value 'No'
$impcsv | Add-Member -MemberType NoteProperty -Name Desired -Value 'ToDo'
$impcsv | Add-Member -MemberType NoteProperty -Name Type -Value 'NaN'
$impcsv | Add-Member -MemberType NoteProperty -Name Description -Value 'NaN'

# Adding a column for each .csv. Cut name until first '.'
# and fill all values with "NaN".
$i = 0
while ($i -lt $csvall.count){
    $impcsv | Add-Member -MemberType NoteProperty -Name $csvall[$i].split(".")[0] -Value 'NaN'
    $i ++
}

# Fill the array with values from the .csv file.
$i = 0
while ($i -lt $csvall.count) {
    $csv = $csvall[$i]
    $col = $csvall[$i].split(".")[0]
    Write-Host "Processing... "$csv
    $myfind = [Collections.Generic.List[Object]]($impcsv)
    foreach ($row in Import-Csv -Path $path$csv) {
        $index = $myfind.FindIndex( {$args[0].Name -eq $row.name} )
        if ($impcsv[$index].Type -eq 'NaN') {
            $impcsv[$index].Type = $row.Type
        }
        if ($impcsv[$index].Description -eq 'NaN') {
            $impcsv[$index].Description = $row.Description
        }
        # Newer versions of vCenter have longer, better descriptions.
        if ($impcsv[$index].Description.Length -lt $row.Description.Length) {
            $impcsv[$index].Description = $row.Description
        }
        $impcsv[$index].($col) = $row.Value
    }
    $i ++
}

# Compare values, if all values are equal, it is a good candidate for the Desired.
# Skip all NaN during this.
foreach ($row in $impcsv){
    $i= 0
    $desired = $true
    $first = $null
    while ($i -lt $csvall.count) {
        $col = $csvall[$i].split(".")[0]
        if ($row.($col) -ne 'NaN' -and $first -eq $null ) {
            $first = $row.($col)
        } 
        if ($row.($col) -ne 'NaN' -and $row.($col) -ne $first) {
            $desired = $false
            break
        }
        $i ++
    }
    if ($desired) {
        $row.Desired = $first
    }
}

# Export Settings as .csv file
$outfile = "VCsummary"+(date -format yyyyMMdd_hhmm)+".csv"
$impcsv | Export-Csv -Delimiter "," -Path "C:\Temp\${outfile}" -NoTypeInformation
#eof
