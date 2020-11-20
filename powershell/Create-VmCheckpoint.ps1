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
        [switch]$version,
        [switch]$debug,
        [Parameter (Mandatory=$true)]
        [array]$hostnames,
        [Parameter (Mandatory=$true)]
        [string]$hostType,
        [Parameter (Mandatory=$true)]
        [string]$certPassword
    )

    function printStatus {
        param (
            [switch]$debug,
            [string]$operation,
            [string]$status,
            [string]$operColor = "Yellow",
            [string]$statColor = "Yellow"
        )
        Write-Host "`r$operation" -ForegroundColor $operColor -NoNewline
        Write-Host "$status" -ForegroundColor $statColor -NoNewline
        Write-Host "               " -NoNewline
    }

    foreach ($server in $hostnames) {
        if (([system.net.dns]::Resolve("$($server)") -ne $null) -and (Test-Connection $server -Count 2)) {
            printStatus -operation "Checking hypervisor for $server :  " -status "Pending..." 
            $hyperV = Invoke-Command -ComputerName $server -ScriptBlock {$(get-item "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters").GetValue("HostName")} -ErrorAction SilentlyContinue
            if (!$hyperV) {
                printStatus -operation "Checking hypervisor for $server :  " -status "Failed" -statColor Red
                if ($debug) {$Error[0,1]}
                continue
            }
            printStatus -operation "Creating checkpoint for $server :  " -status "Pending..."
        } else {
            Write-Host "Connection to $server is failed. " -ForegroundColor Red -NoNewline
            Write-Host "Skiping..." -ForegroundColor Yellow
            continue
        }
        Write-Host
    }





}