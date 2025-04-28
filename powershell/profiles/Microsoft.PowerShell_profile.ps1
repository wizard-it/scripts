(Get-Host).UI.RawUI.CursorSize = 10
(Get-Host).UI.RawUI.WindowTitle = $($(Get-Host).UI.RawUI.WindowTitle) + " :: " + $env:USERNAME

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

function prompt {
    [Security.Principal.WindowsPrincipal]$user = [Security.Principal.WindowsIdentity]::GetCurrent();
    'PS [' + $((Get-ChildItem  Env:Computername).Value) + '] ' + '(' + $((Get-Location).Path.Split("\")[-1]) + ') > '
}

Remove-Module PSReadline
