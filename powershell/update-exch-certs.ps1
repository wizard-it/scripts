function Update-ExchangeCertificates() {
    <#
        .SYNOPSIS
        Обновляет сертификаты на серверах Exchange

        .DESCRIPTION
        Функция Update-ExchangeCertificates оформлена в виде командлета PowerShell и предоставляет администратору средства для обновления сертификатов на серверах Exchange.

        .EXAMPLE
        Обновить сертификаты:
            Create-ADUser -fullName "Достоевский Федор Михайлович" -JobTitle "Великий русский писатель" -OfficeNumber 42 -MailDatabase "Shuvoe Standard Users" -CreateOOF -InternetGroupName "web_allow_basic"

        .NOTES
        Organization: JSC "Gedeon Richter-RUS"
        Author: Kornilov Alexander

    #>
    
    [CmdLetBinding()]
    Param (
    [switch]$version,    
    [Parameter (Mandatory=$true)]
    [string]$username,
    [Parameter (Mandatory=$true)]
    [string]$password,
    [Parameter (Mandatory=$true)]
    [string]$hostname,
    [Parameter (Mandatory=$true)]
    [string]$certPath,
    [Parameter (Mandatory=$true)]
    [string]$certPassword
    )

    $pass = ConvertTo-SecureString $password -AsPlainText -Force
    $cerPass = ConvertTo-SecureString $certPassword -AsPlainText -Force
    $credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $pass
    $exSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$hostname/PowerShell/ -Authentication Kerberos -Credential $credentials -AllowRedirection

    if ( -not (Test-Path -LiteralPath $certPath -PathType Leaf) ) { 
        Write-Host "Can't read new certificate. Aborting..."
        Wait-Event -Timeout 5
        exit    
    }
    if (!$exSession) { 
        Write-Host "Can't connect to host, check creds. Aborting..."
        Wait-Event -Timeout 5
        exit
    }

    Import-Module (Import-PSSession $exSession -AllowClobber) -Global
    $oldcert = Get-ExchangeCertificate -DomainName mail.rg-rus.ru
    Remove-ExchangeCertificate -Thumbprint $oldcert.Thumbprint -Confirm:$false
    Import-ExchangeCertificate -FileData ([Byte[]]$(Get-Content -Path $certpath -Encoding byte -ReadCount 0)) -Password $cerPass

}

