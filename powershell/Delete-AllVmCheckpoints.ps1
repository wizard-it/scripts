function Delete-AllVmCheckpoints() {
    <#
        .SYNOPSIS
        Удаляет все снапшоты виртуальный машин на указанных гипервизорах

        .DESCRIPTION
        Функция Delete-AllVmCheckpoints оформлена в виде командлета PowerShell и предоставляет администратору средство для удаления всех снапшотов виртуальных машин на указанных гипервизорах.

        .EXAMPLE
        Delete-AllVmCheckpoints -hypervisors shv-hv03,shv-hv04 -type hyperv
        
        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Author: Kornilov Alexander

    #>
    
    [CmdLetBinding()]
    Param(
        [Parameter (Mandatory=$true)]
        [array]$hypervisors,
        [string]$type = "hyperv",
        [switch]$version,
        [switch]$track,
        [switch]$dryrun
    )

    function printStatus {
        param (
            [switch]$newline,
            [string]$operation,
            [string]$status,
            [string]$operColor = "Yellow",
            [string]$statColor = "Yellow"
        )
        Write-Host "`r$operation" -ForegroundColor $operColor -NoNewline
        Write-Host "$status" -ForegroundColor $statColor -NoNewline
        Write-Host "               " -NoNewline
        if ($newline) {Write-Host}
    }

    switch -wildcard ($type) {
        "hyperv" {$hvtype = "hyperv"}
        "vmware" {$hvtype = "vmware"}
        "vsphere" {$hvtype = "vmware"}
        default {Write-Host "Uncorrect type of host, use hyperv or vmware."; return 1}
    }

    if (!$track) {$ErrorActionPreference = 'silentlycontinue'}
    foreach ($server in $hypervisors) {
        if (([system.net.dns]::Resolve("$($server)") -ne $null) -and (Test-Connection $server -Count 2)) {
            if ($hvtype -eq "hyperv") {
                printStatus -operation "Calculating VM List against $server : " -status "Pending..." -operColor Green -statColor Yellow
                $vms = Get-Vm -ComputerName $server -ErrorAction SilentlyContinue
                if (!$vms) {printStatus -operation "Calculating VM List against $server : " -status "Fail" -operColor Green -statColor Red -newline; continue}
                if ($track) {$Error[0,1]}
                printStatus -operation "Calculating VM List against $server : " -status "Done" -operColor Green -statColor Yellow -newline
                foreach ($vm in $vms) {
                    printStatus -operation "Deleting all snapshots for $($vm.Name) : " -status "Pending..." -operColor Green -statColor Yellow -newline
                    if ($dryrun) {printStatus -operation "Deleting all snapshots for $($vm.Name) : " -status "Dry Run, Do nothing" -operColor Green -statColor Yellow; continue}
                    $status = Invoke-Command -ComputerName $server -ScriptBlock {try {Remove-VMSnapshot -Name * -VMName $($args[0]) -ErrorAction Stop} Catch [system.exception] {return 1}} -ArgumentList $vm
                    if ($status -eq "1") {
                        printStatus -operation "Deleting all snapshots for $($vm.Name) : " -status "Failed" -statColor Red -newline
                    } else {
                        printStatus -operation "Deleting all snapshots for $($vm.Name) : " -status "Done" -statColor Yellow -newline
                    }
                }
            }
        } else {
            printStatus -operation "Checking network connection to $server :  " -status "Failed" -statColor Red -newline
            continue
        }
    }
}