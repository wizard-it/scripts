$hostname = $env:COMPUTERNAME
$DOMAIN = $env:USERDNSDOMAIN.ToLower()
$MAILDOMAIN = $env:USERDNSDOMAIN.ToLower() -replace '^\w+.'

$WBReport = Get-WBSummary

if ($WBReport.LastSuccessfulBackupTime.Date -eq $(get-date).Date) {
    $subject = "SUCCESS - Windows Backup on $($hostname)"
    } else {
        $subject = "FAILED - Windows Backup on $($hostname)"
    }


$body += "{0,-19}{1,-3}{2,-35}{3,-1}" -f "Last Success Backup"," : ",$WBReport.LastSuccessfulBackupTime.ToString(),"<br>"
$body += "{0,-19}{1,-3}{2,-35}" -f "Path"," : ",$WBReport.LastSuccessfulBackupTargetPath

$BodyHTML = "
    <!DOCTYPE html>
    <html>
        <head></head>
        <body>$body</body>
    </html>
    "
Send-MailMessage -SmtpServer "mail.rg-rus.ru" -Subject $subject -From "wb-$($hostname.ToLower())@$($MAILDOMAIN)"`
-To "administrators@$($MAILDOMAIN)" -BodyAsHtml $BodyHTML -Encoding UTF8

Clear-Variable body,WBReport,BodyHTML,hostname,DOMAIN,MAILDOMAIN,subject