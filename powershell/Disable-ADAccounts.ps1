# The script disables users and computers accounts which didn't authenticated for a configured time (default: 2 months)

# Main settings
$month = -2 # Minus!

# Mail settings
$smtpServer = "mail.rg-rus.ru"
$mailFrom = "disable-adaccountss@rg-rus.ru"
$mailTo = "KornilovAA@rg-rus.ru", "piskunovdv@rg-rus.ru", "Shevchuk@rg-rus.ru", "FursaevAA@rg-rus.ru", "KarasevMS@rg-rus.ru", "NarkhovVV@rg-rus.ru", "ShirokovNM@rg-rus.ru"
$mailSubject = "Disabled AD Accounts"

# AD credentials settings
$userName = "shuvoe\ldap_cleaner"
$userPassword = ConvertTo-SecureString -String "@ICanMoveObjects@" -AsPlainText -Force
$cred = New-Object -TypeName PSCredential -ArgumentList $userName, $userPassword

# OU for searching users and computers
$ouUsers = "OU=RGr Users,DC=SHUVOE,DC=RG-RUS,DC=RU"
$ouComputers = "OU=RGr Computers,DC=SHUVOE,DC=RG-RUS,DC=RU"
# OU for moving disabled accounts
$ouDisabledUsers = "OU=Users,OU=Disabled,DC=SHUVOE,DC=RG-RUS,DC=RU"
$ouDisabledComputers = "OU=Computers,OU=Disabled,DC=SHUVOE,DC=RG-RUS,DC=RU"
# exclude users from the group 
$FilteredGroup  = Get-ADGroup "RUDIS Users"

# Filter for Users
$Userfilter = 'company -eq "Gedeon Richter RUS" -and PasswordNeverExpires -eq "false" -and memberof -ne "{0}"' -f $FilteredGroup.DistinguishedName

#
$disabledUsers = @()
$disabledComputers = @()

# Getting users list
$users = Get-ADUser -SearchBase $ouUsers -Filter $Userfilter -Properties LastLogonTimeStamp, WhenCreated -Credential $cred


# Users disabling
$users | ForEach-Object {
    $lastLogonDate = [datetime]::FromFileTime($_.LastLogonTimeStamp)
    if ($lastLogonDate -lt $(Get-Date).AddMonths($month)) {
     #if (($lastLogonDate -lt $(Get-Date).AddMonths($month)) -and ($_.WhenCreated -gt $(Get-Date).AddDays(-7))) {
        Disable-ADAccount -Identity $_ -Credential $cred
        Move-ADObject -Identity $_ -TargetPath $ouDisabledUsers -Credential $cred
        $disabledUsers += $_.SamAccountName
    }
}
# Getting computers list
# $computers = Get-ADComputer -SearchBase $ou_computers -Filter {(Name -notlike "SCTRM*") -and (Name -notlike "MB*") -and (Name -notlike "NB*")} -Properties LastLogonTimeStamp -Credential $cred
$computers = Get-ADComputer -SearchBase $ouComputers -Filter * -Properties LastLogonTimeStamp -Credential $cred | Where-Object {$_.Name -NotMatch "^PB|NB|TRC|POS|SCTRM|MB"}
# Computers disabling
$computers | ForEach-Object {
    if ([datetime]::FromFileTime($_.LastLogonTimeStamp) -lt $(Get-Date).AddMonths($month)) {
        Write-Host $_.Name
        Disable-ADAccount -Identity $_ -Credential $cred
        Move-ADObject -Identity $_ -TargetPath $ouDisabledComputers -Credential $cred
        $disabledComputers += $_.Name
    }
}

# Forming mail body in plain text
$mailBody = "Список отключенных пользователей, не входивших в сеть более 2-х месяцев:" + "`n" + $([string]::Join("`n", $disabledUsers)) + "`n`n" + `
"Список отключенных компьютеров, не входивших в сеть более 2-х месяцев:" + "`n" + $([string]::Join("`n", $disabledComputers))

# Sending mail message
Send-MailMessage -Body $mailBody -Encoding UTF8 -From $mailFrom -To $mailTo -SmtpServer $smtpServer -Subject $mailSubject