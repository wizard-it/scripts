<#
    .SYNOPSIS
    Удаляет все неиспользуемые жесткие диски вм на гипервизоре

    .DESCRIPTION
    Удаляет все неиспользуемые жесткие диски вм на гипервизоре

    .EXAMPLE
    Delete-UnusedVDisks
    
    .NOTES
    Organization: AO "Gedeon Richter-RUS"
    Author: Kornilov Alexander
#>

$hyperv = Get-VMHost
$vms = Get-Vm
$files = Get-ChildItem $hyperv2.VirtualHardDiskPath

# Check hyperv is exist
if ($hyperv) {
    Write-Host -ForegroundColor red "Can't get hypervisor properties...Exiting)."
    return 1
}

foreach ($vm in $vms) {
    Write-Host "Deleting all snapshots for $($vm.Name)"
    Remove-VMSnapshot -VMName $vm.Name
}