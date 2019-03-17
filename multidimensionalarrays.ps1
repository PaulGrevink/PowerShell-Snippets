Source: https://devblogs.microsoft.com/scripting/easily-create-and-manipulate-an-array-of-arrays-in-powershell/

$a = Get-Service
$b = Get-Process
$c = Get-Date

# One dimensrional array
$array = @()
$array += $a
$array += $b
$array += $c
Write-Host $array.count

# multi-dimensional array
$array2 = $a,$b,$c
Write-Host $array2.count

# Multi-dimensional which can be used in a loop
$array3 = $a
# Next line can be used in a loop
$array3 = $array3,$c
Write-Host $array3.count
