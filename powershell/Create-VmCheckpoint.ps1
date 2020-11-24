function Create-VmCheckpoint() {
    <#
        .SYNOPSIS
        Создает контрольную точку виртуального хоста

        .DESCRIPTION
        Функция Create-VmCheckpoint оформлена в виде командлета PowerShell и предоставляет администратору средство для создания контрольной точки виртуального хоста

        .EXAMPLE
        Create-VmCheckpoint -ComputerName shv-vdc01

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
            $cred = $credPath
        } else {
            $cred = Get-Credential
        }
    }

    [string]$datestr = Get-Date -Format "dd_MM_yyyy_HHmm"
    $cpName = "auto-$datestr"
    
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
                New-SshSession -ComputerName $server -Credential $cred -ErrorAction SilentlyContinue >$null 2>&1
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
            printStatus -operation "Creating checkpoint for $server :  " -status "Pending..." -statColor White
            $status = Invoke-Command -ComputerName $hyperV -ScriptBlock {try { Checkpoint-VM -Name $($args[0]) -SnapshotName $($args[1]) -ErrorAction Stop} Catch [system.exception] {return 1}} -ArgumentList $vmName, $cpName
            if ($track) {Write-Host "status: $status"}
            if ($status -eq "1") {
                printStatus -operation "Creating checkpoint for $server :  " -status "Failed" -statColor Red -newline
                if ($track) {
                    Invoke-Command -ComputerName $hyperV {Checkpoint-VM -Name $vmName -SnapshotName $cpName -Verbose}
                }
            } else {
                printStatus -operation "Creating checkpoint for $server :  " -status "Done" -statColor Green -newline
                Remove-PSSession $session
            }            
        } else {
            printStatus -operation "Checking network connection to $server :  " -status "Failed" -statColor Red -newline
            continue
        }
    }
}