<#
    .SYNOPSIS
    Обновляет пакеты на клиенте

    .DESCRIPTION
    Обновляет пакеты на клиенте

    .EXAMPLE

    .NOTES
    Organization: AO "Gedeon Richter-RUS"
    Author: Kornilov Alexander
#>

$chocoVer = $(choco -v)
$installScript = "\\shuvoe.rg-rus.ru\NETLOGON\choco\Install-Chocolatey.ps1"
$localRepName = "rgrus"
$localRepPath = "http://nexus.shuvoe.rg-rus.ru/repository/chocolatey/"
$remoteRepName = "chocolatey"
$remoteRepPath = "https://community.chocolatey.org/api/v2/"
$defaultRepName = $localRepName
$chocoPath = "http://nexus.shuvoe.rg-rus.ru/repository/chocolatey/chocolatey/0.11.3"
$pkgList = "microsoft-teams", "zoom", "notepadplusplus"

if (!$chocoVer) {
    Write-Host "Can't define chocolatey pkg. Trying to install."
    & $installScript -ChocolateyDownloadUrl $chocoPath
}

$check = $(choco)
if ($check) {
    $srcList = $(choco source list --nocolor --limitoutput)
    if ($srcList -match "$remoteRepName") {
        Write-Host "Removing default repository"
        $(choco source remove -n $remoteRepName -y)
    }
    if ( -not ($srcList -match "$localRepName") ) {
        Write-Host "Adding local repository"
        $(choco source add -s $localRepPath -n $localRepName)
    }
    Write-Host "Starting update of packages"
    foreach ($name in $pkgList) {
        $(choco upgrade $name -y)
    }
} else {
    Write-Host "Installing of chocolatey is failed. Exiting..."
    return 1
}

