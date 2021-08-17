#
# Module: Deploy winlogbeat to target
# Author: Alexander Kornilov 2021
#

$defaultName = "winlogbeat"
function deployBeat {
    param (
        [string]$path = "C:\Windows\winlogbeat",
        [string]$source = "\\fsc01\softdistrib$\winlogbeat"
    )  
    robocopy $source $path /mir /z /e /R:1 /W:10 /mt:2
}

function installService {
    param (
        [string]$svcName = "winlogbeat",
        [string]$homeDir = "C:\Windows\winlogbeat"
    )
    New-Service -name $svcName -displayName $svcName -binaryPathName "`"$homeDir\winlogbeat.exe`" --environment=windows_service -c `"$homeDir\winlogbeat.yml`" --path.home `"$homeDir`" --path.data `"$env:PROGRAMDATA\winlogbeat`" --path.logs `"$env:PROGRAMDATA\winlogbeat\logs`" -E logging.files.redirect_stderr=true"

# Attempt to set the service to delayed start using sc config.
Try {
  Start-Process -FilePath sc.exe -ArgumentList "config $svcName start= delayed-auto"
}
Catch { Write-Host -f red "An error occured setting the service to delayed start." }
}

# Main
if ( -not (Get-Service $defaultName -ErrorAction SilentlyContinue) ) { 
    deployBeat
    installService
# Try to start svc
    Start-Service -Name $defaultName
    return
} else {
    Write-Host "Already deployed, skipping..."
}