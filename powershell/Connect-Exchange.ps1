Function Connect-Exchange {
    <#
        .SYNOPSIS
        Подключает сессию почтового сервера типа Exchange

        .DESCRIPTION
        Функция Connect-Exchange оформлена в виде командлета PowerShell и предоставляет администратору средство для подключения консоли управления сервером Exchange.

        .EXAMPLE
        Connect-Exchange
        
        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Authors:  Piskunov Dmitry
                  Kornilov Alexander

    #>
    $ExchangeServers = Get-ADGroup "Exchange Servers" | Get-ADGroupMember | Where-Object {$_.objectClass -match "computer"} | select Name | sort name
    $CredentialsExch = Get-Credential -Message "Enter your Exchange admin credentials"
    if (!$ExchangeServers) {return $(Write-Host -ForegroundColor red "Can't get exchange servers for connecting... Operation has been canceled.")}
    if (!$CredentialsExch) {return $(Write-Host -ForegroundColor red "Wrong Credentials for connect... Operation has been canceled.")}
    Write-Host -ForegroundColor green "Please choose a server:" 
    For ($i=0; $i -lt $ExchangeServers.Count; $i++)  {
      Write-Host "$($i+1): $($ExchangeServers[$i].Name)"
    }

    [int]$number = Read-Host "Press the number to select a server: "
    if ($number -in (1..$($ExchangeServers.Count))) {
      Write-Host -ForegroundColor green "You've selected $($ExchangeServers[$number-1].name)."
    } else {
      return $(Write-Host -ForegroundColor red "You've selected wrong number... Operation has been canceled.")
    }

    
    try {
      $ExchOPSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$($ExchangeServers[$number-1].name)/PowerShell/ -Authentication Kerberos -Credential $CredentialsExch -AllowRedirection -ErrorAction Stop
    } catch {
      return $(Write-Host -Foregroundcolor red $_.Exception.Message)
    }
    Import-Module (Import-PSSession $ExchOPSession -DisableNameChecking -AllowClobber) -Global
    
    Clear-Variable -Name CredentialsExch, ExchOPSession, ExchangeServers

}