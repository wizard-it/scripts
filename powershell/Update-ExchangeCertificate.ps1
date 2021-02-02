function Update-ExchangeCertificate() {
    <#
        .SYNOPSIS
        Обновляет сертификат на серверax Exchange

        .DESCRIPTION
        Функция Update-ExchangeCertificate оформлена в виде командлета PowerShell и предоставляет администратору средства для обновления сертификата на серверe Exchange.

        .EXAMPLE
        Обновить сертификат на сервере shv-vexch01.shuvoe.rg-rus.ru,shv-vexch02.shuvoe.rg-rus.ru:
            Update-ExchangeCertificate -credPath "C:\TEMP\cred.xml" -certPath \\server1\share1\exchange.pfx -certPassword m@sterP@ssword -hostnames shv-vexch01.shuvoe.rg-rus.ru,shv-vexch02.shuvoe.rg-rus.ru
        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Author: Kornilov Alexander

    #>
    
    [CmdLetBinding()]
    Param (
    [switch]$version,
    [Parameter (Mandatory=$true)]
    [string]$credPath,
    [Parameter (Mandatory=$true)]
    [array]$hostnames,
    [string]$domain = "mail.rg-rus.ru",
    [Parameter (Mandatory=$true)]
    [string]$certPath,
    [Parameter (Mandatory=$true)]
    [string]$certPassword
    )

    $cerPass = ConvertTo-SecureString $certPassword -AsPlainText -Force
    $credentials = Import-CliXml -Path $credPath
    
    if ( -not (Test-Path -LiteralPath $credPath -PathType Leaf) ) { 
        Write-Host "Can't read credentials from file $credPath . Aborting..."
        Wait-Event -Timeout 2
        return 1
    }

    if ( -not (Test-Path -LiteralPath $certPath -PathType Leaf) ) { 
        Write-Host "Can't read new certificate. Aborting..."
        Wait-Event -Timeout 2
        return 1
    }

    foreach ($server in $hostnames)
    {
        $exSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$server/PowerShell/ -Authentication Kerberos -Credential $credentials -AllowRedirection
        if (!$exSession) { 
            Write-Host "Can't connect to host $server, check creds. Skiping..."
            Wait-Event -Timeout 2
            continue
        }
        Import-Module (Import-PSSession $exSession -AllowClobber) -Global
        $oldcert = Get-ExchangeCertificate -DomainName $domain
        if ($oldcert) { Remove-ExchangeCertificate -Thumbprint $oldcert.Thumbprint -Confirm:$false }
        Import-ExchangeCertificate -FileData ([Byte[]]$(Get-Content -Path $certpath -Encoding byte -ReadCount 0)) -Password $cerPass
        $newcert = Get-ExchangeCertificate -DomainName $domain
        if ($newcert) { Enable-ExchangeCertificate -Services IIS,IMAP,POP -Thumbprint $newcert.Thumbprint -NetworkServiceAllowed }
    }

}
