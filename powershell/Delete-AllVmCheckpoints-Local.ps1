<#
    .SYNOPSIS
    Удаляет все снапшоты виртуальный машин на локальном гипервизоре

    .DESCRIPTION
    Удаляет все снапшоты виртуальный машин на локальном гипервизоре

    .EXAMPLE
    Delete-AllVmCheckpoints
    
    .NOTES
    Organization: AO "Gedeon Richter-RUS"
    Author: Kornilov Alexander
#>

$vms = Get-Vm
foreach ($vm in $vms) {
    Write-Host "Deleting all snapshots for $($vm.Name)"
    Remove-VMSnapshot -VMName $vm.Name
}