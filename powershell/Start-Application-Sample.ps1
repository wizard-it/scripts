$target = "$env:LOCALAPPDATA\Microsoft\Teams\Update.exe"
#$trace = 1

if ( Test-Path -Path $target -PathType Leaf ) {
    if ($trace) {Write-Host "[INFO] Run update process"}
    Start-Sleep 2
    & "$PSScriptRoot\Teams.exe" -s
}
