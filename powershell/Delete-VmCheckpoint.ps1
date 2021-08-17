function Delete-VmCheckpoint() {
    <#
        .SYNOPSIS
        Удаляет контрольную точку виртуального хоста

        .DESCRIPTION
        Функция Delete-VmCheckpoint оформлена в виде командлета PowerShell и предоставляет администратору средство для удаления контрольных точек виртуального хоста

        .EXAMPLE
        Delete-VmCheckpoint -hostnames shv-vac01, shv-vbpm01 -hosttype windows
        Delete-VmCheckpoint -hostnames shv-vnetbox01, shv-vapp07 -hosttype linux


        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Author: Kornilov Alexander

    #>
    param(
        [Parameter (Mandatory=$true)]
        [array]$hostnames,
        [Parameter (Mandatory=$true)]
        [string]$hosttype,
        [switch]$version,
        [switch]$track,
        [switch]$all,
        [switch]$dryrun,
        [string]$credPath
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

    switch -wildcard ($hosttype) {
        "windows" {$type = "win"}
        "linux" {$type = "lin"}
        default {Write-Host "Uncorrect type of host, use linux or windows."; return 1}
    }

    if ($track) {write-Host "hosttype: $hosttype , type: $type"}
    if ($type -eq "lin") {
        if ($credPath) {
            $cred = Import-CliXML -Path $credPath
        } else {
            $cred = Get-Credential
        }
    }

    foreach ($server in $hostnames) {
        if (([system.net.dns]::Resolve("$($server)") -ne $null) -and (Test-Connection $server -Count 2)) {
            printStatus -operation "Checking network connection to $server :  " -status "Done" -statColor Green -newline
            printStatus -operation "Checking hypervisor for $server :  " -status "Pending..." -statColor White
            if ($type -eq "win") {
                $hyperV = Invoke-Command -ComputerName $server -ScriptBlock {$(get-item "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters").GetValue("HostName")} -ErrorAction SilentlyContinue
                $vmName = Invoke-Command -ComputerName $server -ScriptBlock {$(get-item "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters").GetValue("VirtualMachineName")} -ErrorAction SilentlyContinue
                if (!$hyperV -or !$vmName) {
                    printStatus -operation "Checking hypervisor for $server :  " -status "Failed" -statColor Red -newline
                    if ($track) {$Error[0,1]}
                    continue
                } else {
                    printStatus -operation "Checking hypervisor for $server :  " -status "Done" -statColor Green -newline
                    if ($track) {Write-Host "HyperV Host: $hyperV , VM name: $vmName"}
                }
            }
            if ($type -eq "lin") {
                New-SshSession -ComputerName $server -Credential $cred -AcceptKey -ErrorAction SilentlyContinue >$null 2>&1
                [string]$hyperV = $(Invoke-SSHCommand -Index 0 -Command "strings /var/lib/hyperv/.kvp_pool_3 | grep -A1 HostName | tail -1" -ErrorAction SilentlyContinue).Output
                [string]$vmName = $(Invoke-SSHCommand -Index 0 -Command "strings /var/lib/hyperv/.kvp_pool_3 | grep -A1 VirtualMachineName | tail -1" -ErrorAction SilentlyContinue).Output
                Get-SSHSession | Remove-SSHSession -ErrorAction SilentlyContinue >$null 2>&1
                if (!$hyperV -or !$vmName) {
                    printStatus -operation "Checking hypervisor for $server :  " -status "Failed" -statColor Red -newline
                    if ($track) {$Error[0,1]}
                    continue
                } else {
                    printStatus -operation "Checking hypervisor for $server :  " -status "Done" -statColor Green -newline
                    if ($track) {Write-Host "HyperV Host: $hyperV , VM name: $vmName"}
                }
            }
            if ($dryrun) {Write-Host "Dry Run..."; continue}
            printStatus -operation "Removing checkpoint for $server :  " -status "Pending..." -statColor White
            if ($all) {
                $status = Invoke-Command -ComputerName $hyperV -ScriptBlock {try {Remove-VMSnapshot -VMName $($args[0]) -ErrorAction Stop} Catch [system.exception] {return 1}} -ArgumentList $vmName, $cpName
            } else {
                $checkpoints = Invoke-Command -ComputerName $hyperV -ScriptBlock {Get-VMSnapshot -VMName $($args[0]) | Where-Object {$_.Name -match "auto"} | Select-Object Name} -ArgumentList $vmName, $cpName
                foreach ($cp in $checkpoints) {
                    $cpName = $cp.Name
                    $status = Invoke-Command -ComputerName $hyperV -ScriptBlock {try {Remove-VMSnapshot -VMName $($args[0]) -Name $($args[1]) -ErrorAction Stop} Catch [system.exception] {return 1}} -ArgumentList $vmName, $cpName
                }
            }
            if ($status -eq "1") {
                printStatus -operation "Removing checkpoint for $server :  " -status "Failed" -statColor Red -newline
                if ($track) {
                    Invoke-Command -ComputerName $hyperV -ScriptBlock {Remove-VMSnapshot -Name $($args[0]) -Verbose} -ArgumentList $vmName, $cpName
                }
            } else {
                printStatus -operation "Removing checkpoint for $server :  " -status "Done" -statColor Green -newline
            }            
        } else {
            printStatus -operation "Checking network connection to $server :  " -status "Failed" -statColor Red -newline
            continue
        }
    }
}