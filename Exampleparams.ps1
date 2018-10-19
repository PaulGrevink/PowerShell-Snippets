# Exampleparams.ps1

Param (
        # Switch
        [Switch]$Myswitch,
        # Input validation
        [Parameter(mandatory=$true)]
        [ValidateSet("ABC","XYZ")]
        [String]$Environment
)

function main()
{
    if($Myswitch)
    {
        Write-Host "Switch myswitch is set."
    }

    if ($Environment -eq "ABC")
    {
        Write-Host "Parameter Environment is now ABC"
    }

    if ($Environment -eq "XYZ")
    {
        Write-Host "Parameter Environment is now XYZ"
    }
}

main

# To see switch in action run
# PS> Exampleparams -Myswitch
#
# parameter $Environment is mandatory, the value is validated
# PS> Exampleparams -Environment XYZ
#
# Swiches en parameters can be combined
# PS> Exampleparams -Myswitch -Environment XYZ
