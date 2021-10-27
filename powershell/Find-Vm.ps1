function Find-Vm() {
    <#
        .SYNOPSIS
        Выводит информацию о виртуальном машине

        .DESCRIPTION
        Функция Find-Vm оформлена в виде командлета PowerShell и предоставляет администратору средство для идентификации виртуальной станции Hyper-V.

        .EXAMPLE
        Find-Vm -path "H:\Обмен\test.txt"
        Find-Vm -path "H:\Обмен\test.txt" -trustList @{"MYSERVER\Administrators","MYDOMAIN\Administrators"} -accessList @{"MYDOMAIN\Administrators"}
        Find-Vm -path "H:\Обмен\test.txt" -recover
        
        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Author: Kornilov Alexander

    #>
    
    [CmdLetBinding()]
    Param(
        [Parameter (Mandatory=$true)]
        [array]$hostnames,
        [Parameter (Mandatory=$true)]
        [ValidateSet("windows","linux")][string]$hosttype,
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

    switch -wildcard ($hosttype) {
        "windows" {$type = "win"}
        "linux" {$type = "lin"}
        default {Write-Host "Uncorrect type of host, use linux or windows."; return 1}
    }

    if ($type -eq "lin") {
        if ($credPath) {
            $cred = Import-CliXML -Path $credPath
        } else {
            $cred = Get-Credential
        }
    }

    if (!$track) {$ErrorActionPreference = 'silentlycontinue'}
    foreach ($server in $hostnames) {
        if (([system.net.dns]::Resolve("$($server)") -ne $null) -and (Test-Connection $server -Count 2)) {
            if ($type -eq "win") {
                $hyperV = Invoke-Command -ComputerName $server -ScriptBlock {$(get-item "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters").GetValue("HostName")} -ErrorAction SilentlyContinue
                $vmName = Invoke-Command -ComputerName $server -ScriptBlock {$(get-item "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters").GetValue("VirtualMachineName")} -ErrorAction SilentlyContinue
                if (!$hyperV -or !$vmName) {
                    if ($track) {$Error[0,1]}
                    continue
                }
            }
            if ($type -eq "lin") {
                New-SshSession -ComputerName $server -Credential $cred -AcceptKey -ErrorAction SilentlyContinue >$null 2>&1
                [string]$hyperV = $(Invoke-SSHCommand -Index 0 -Command "strings /var/lib/hyperv/.kvp_pool_3 | grep -A1 HostName | tail -1" -ErrorAction SilentlyContinue).Output
                [string]$vmName = $(Invoke-SSHCommand -Index 0 -Command "strings /var/lib/hyperv/.kvp_pool_3 | grep -A1 VirtualMachineName | tail -1" -ErrorAction SilentlyContinue).Output
                Get-SSHSession | Remove-SSHSession -ErrorAction SilentlyContinue >$null 2>&1
                if (!$hyperV -or !$vmName) {
                    if ($track) {$Error[0,1]}
                    continue
                }
            }
        $cluster = Get-Cluster $hyperV
        printStatus -operation "Hostname: " -status $($([system.net.dns]::Resolve($server)).Hostname) -operColor Green -statColor Yellow -newline
        printStatus -operation "Host Address: " -status $($([system.net.dns]::Resolve($server)).AddressList.IPAddressToString) -operColor Green -statColor Yellow -newline
        printStatus -operation "Hyper-V: " -status $hyperV -operColor Green -statColor Yellow -newline
        printStatus -operation "Vm Name: " -status $vmName -operColor Green -statColor Yellow -newline
        printStatus -operation "Cluster: " -status $cluster -operColor Green -statColor Yellow -newline
        Write-Host
        } else {
            Write-Host "VM $server is missing..."
            Write-Host
            continue
        }
    }
}
