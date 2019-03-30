# Source: https://devblogs.microsoft.com/scripting/easily-create-and-manipulate-an-array-of-arrays-in-powershell/

$a = Get-Service
$b = Get-Process
$c = Get-Date

# One dimensrional array
Write-Host "One dimensional array"
$array1 = @()
Write-Host $array1.count
$array1 += $a
Write-Host $array1.count
$array1 += $b
Write-Host $array1.count
$array1 += $c
Write-Host $array1.count

# multi-dimensional array
Write-Host "Multi dimensional array"
$array2 = @()
Write-Host $array2.count
$array2 = $a,$b,$c
Write-Host $array2.count

# Multi-dimensional which can be used in a loop
# https://stackoverflow.com/questions/6157179/append-an-array-to-an-array-of-arrays-in-powershell

Write-Host "Multi dimensional array used in a loop"
[Array]$array3 = @()
Write-Host $array3.count
$array3 += , $a
Write-Host $array3.count
Write-Host $array3[0]
$array3 += , $b
Write-Host $array3.count
$array3 += , $c
Write-Host $array3.count
Write-Host $array3[2]

