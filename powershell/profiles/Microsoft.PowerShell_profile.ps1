(Get-Host).UI.RawUI.ForegroundColor = "DarkYellow"
(Get-Host).UI.RawUI.BackgroundColor = "Black"
(Get-Host).UI.RawUI.CursorSize = 10
(Get-Host).UI.RawUI.WindowTitle = $($(Get-Host).UI.RawUI.WindowTitle) + " :: " + $env:USERNAME + "@" + "$env:COMPUTERNAME"

if (Get-Module -ListAvailable -Name cmatrix) {
    Set-ScreenSaverTimeout -Seconds 120
    Write-Host "Send Enable-ScreenSaver to run screensaver application"
}

function ConvertTo-Encoding ([string]$From, [string]$To){  
    Begin{  
        $encFrom = [System.Text.Encoding]::GetEncoding($from)  
        $encTo = [System.Text.Encoding]::GetEncoding($to)  
    }  
    Process{  
        $bytes = $encTo.GetBytes($_)  
        $bytes = [System.Text.Encoding]::Convert($encFrom, $encTo, $bytes)  
        $encTo.GetString($bytes)  
    }  
}

Write-Host -ForegroundColor Green "Personal settings have been loaded"; Write-Host